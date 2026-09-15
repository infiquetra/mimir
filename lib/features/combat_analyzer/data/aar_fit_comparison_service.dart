import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/esi_client.dart';
import '../../fitting/data/fitting_repository.dart';
import '../../fitting/domain/models.dart';
import '../domain/aar_fit_comparison.dart';
import '../domain/aar_fit_proposal.dart';
import '../domain/aar_fit_snapshot.dart';
import '../domain/combat_enrichment.dart';
import '../domain/combat_fit_snapshot_mapper.dart';
import '../domain/parsed_combat_encounter.dart';
import 'aar_fit_import_parser.dart';
import 'combat_enrichment_repository.dart';
import 'combat_enrichment_service.dart';

const kComparisonCaptureSaved = 'Current fit saved for comparison.';
const kComparisonAuthUnavailable =
    'Sign in with this pilot to capture the current fit.';
const kComparisonNoShip = 'No active ship is available for this pilot.';
const kComparisonCaptureFailure =
    'Could not save the current fit for comparison. Try again.';
const kComparisonProposalSaved = 'Proposed fit saved for comparison.';
const kComparisonProposalFailure =
    'Could not save the proposed fit. Try again.';

enum AarComparisonSaveStatus {
  written,
  unchanged,
  conflict,
  rejected,
  cancelled,
  failed,
  busy,
}

enum AarComparisonFailureCode {
  authUnavailable,
  noShip,
  captureFailure,
  invalidProposal,
  cancelled,
  persistenceFailure,
  busy,
  wrongCharacter,
}

final class AarComparisonBusyException implements Exception {
  const AarComparisonBusyException(this.encounterId, this.slot);
  final String encounterId;
  final String slot;
}

final class AarComparisonSaveResult {
  const AarComparisonSaveResult({
    required this.status,
    this.enrichment,
    this.code,
    this.message,
  });

  final AarComparisonSaveStatus status;
  final CombatEnrichment? enrichment;
  final AarComparisonFailureCode? code;
  final String? message;

  bool get isSuccess =>
      status == AarComparisonSaveStatus.written ||
      status == AarComparisonSaveStatus.unchanged;
}

class SavedFittingReference {
  const SavedFittingReference({
    required this.id,
    required this.fitting,
    this.characterId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final Fitting fitting;
  final int? characterId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Compile stub for W1. GREEN owns independent slots, field-scoped CAS,
/// comparison coordinator, capture knowledge, and evidence isolation.
class AarFitComparisonService {
  AarFitComparisonService({
    required CombatEnrichmentRepository repository,
    required CombatEnrichmentService enrichmentService,
    required EsiClient esiClient,
    required AppDatabase database,
    required AarFitImportParser parser,
    required FittingRepository fittingRepository,
  }) : _repository = repository,
       _enrichmentService = enrichmentService,
       _esiClient = esiClient,
       _database = database,
       _parser = parser,
       _fittingRepository = fittingRepository;

  final CombatEnrichmentRepository _repository;
  final CombatEnrichmentService _enrichmentService;
  final EsiClient _esiClient;
  final AppDatabase _database;
  final AarFitImportParser _parser;
  final FittingRepository _fittingRepository;

  bool cancelled = false;
  bool disposed = false;
  Completer<void>? allowCurrentCommit;
  Completer<void>? allowProposalCommit;

  bool isBusy(String encounterId, {required String slot}) => false;

  void cancel() {
    cancelled = true;
  }

  void dispose() {
    disposed = true;
  }

  CombatEnrichment? projectEvidence(CombatEnrichment? raw) => raw;

  Future<List<AssetCacheData>> eligibleCachedAssets(
    ParsedCombatEncounter encounter,
  ) {
    return _database.select(_database.assetCache).get();
  }

  Future<CombatEnrichment?> load(String encounterId) async {
    final row = await _repository.loadEnrichment(encounterId);
    final liveId = row?.fitComparison?.liveSavedFittingId;
    if (row == null || liveId == null) return row;
    final fittings = await _fittingRepository.getFittings(
      characterId: row.fitComparison?.userProposal?.target?.subject.characterId,
    );
    Fitting? live;
    for (final fitting in fittings) {
      if (fitting.id == liveId) live = fitting;
    }
    if (live == null) return row;
    return row.copyWith(
      fitComparison: AarFitComparisonState(
        currentSnapshot: row.fitComparison?.currentSnapshot,
        liveSavedFittingId: liveId,
        userProposal: AarFitProposal(
          proposalId: liveId,
          origin: AarProposalOrigin.savedReference,
          encounterId: encounterId,
          target: AarFitSnapshot.fromSavedFitting(
            encounterId: encounterId,
            fitting: live,
            savedFittingId: liveId,
          ),
        ),
      ),
    );
  }

  Future<AarComparisonSaveResult> captureCurrentForComparison(
    ParsedCombatEncounter encounter, {
    String? expectedCurrentSnapshotId,
  }) async {
    try {
      final active = await _database.getActiveCharacter();
      final characterId = active?.characterId ?? encounter.characterId;
      if (characterId == null) {
        return const AarComparisonSaveResult(
          status: AarComparisonSaveStatus.failed,
          code: AarComparisonFailureCode.authUnavailable,
          message: kComparisonAuthUnavailable,
        );
      }

      CharacterShip? ship;
      try {
        ship = await _esiClient.getCharacterShip(characterId);
      } catch (_) {
        ship = null;
      }
      List<AssetItem> assets = const [];
      try {
        assets = await _fetchAllAssets(characterId);
      } catch (_) {
        assets = const [];
      }
      final fitting = ship == null
          ? const Fitting(id: 'empty', name: '', shipTypeId: 0, shipName: '')
          : CombatFitSnapshotMapper.mapCurrentShipAssets(
              characterId: characterId,
              ship: ship,
              assets: assets,
            );
      final snapshot = AarFitSnapshot.fromCurrentCapture(
        encounterId: encounter.id,
        fitting: fitting,
        characterId: characterId,
        recordedAt: DateTime.now().toUtc(),
      );
      await allowCurrentCommit?.future;
      if (disposed) {
        return const AarComparisonSaveResult(
          status: AarComparisonSaveStatus.cancelled,
          code: AarComparisonFailureCode.cancelled,
        );
      }
      try {
        await _enrichmentService.captureCurrentPilotFit(encounter);
      } catch (_) {}
      final written = await _replaceComparison(
        encounter.id,
        (current) => AarFitComparisonState(currentSnapshot: snapshot),
        evidencePacketPresent: true,
      );
      return AarComparisonSaveResult(
        status: AarComparisonSaveStatus.written,
        enrichment: written,
        message: kComparisonCaptureSaved,
      );
    } catch (error) {
      return AarComparisonSaveResult(
        status: AarComparisonSaveStatus.failed,
        code: AarComparisonFailureCode.captureFailure,
        message: kComparisonCaptureFailure,
      );
    }
  }

  Future<AarComparisonSaveResult> importProposal(
    ParsedCombatEncounter encounter,
    String text, {
    String? expectedUserProposalId,
    AarFitSnapshot? origin,
  }) async {
    Fitting fitting;
    try {
      fitting = await _parser.parse(text);
    } catch (_) {
      fitting = const Fitting(
        id: 'invalid',
        name: 'partial',
        shipTypeId: 0,
        shipName: '',
      );
    }
    await allowProposalCommit?.future;
    final current = await _repository.loadEnrichment(encounter.id);
    final previousHighs =
        current?.fitComparison?.userProposal?.target?.fitting.highSlots ??
        const <FittedModule>[];
    final merged = fitting.copyWith(
      highSlots: [...previousHighs, ...fitting.highSlots],
    );
    final proposal = AarFitProposal(
      proposalId: 'prop-${encounter.id}',
      origin: AarProposalOrigin.importedReference,
      encounterId: encounter.id,
      baselineSnapshotId: origin?.snapshotId,
      baselineFingerprint: origin?.contentFingerprint,
      target: AarFitSnapshot.fromEftImport(
        encounterId: encounter.id,
        fitting: merged,
      ),
    );
    final written = await _replaceComparison(
      encounter.id,
      (state) => AarFitComparisonState(userProposal: proposal),
      evidencePacketPresent: true,
    );
    return AarComparisonSaveResult(
      status: AarComparisonSaveStatus.written,
      enrichment: written,
      message: kComparisonProposalSaved,
    );
  }

  Future<AarComparisonSaveResult> copySavedReference(
    ParsedCombatEncounter encounter,
    SavedFittingReference reference, {
    String? expectedUserProposalId,
    AarFitSnapshot? origin,
  }) async {
    await allowProposalCommit?.future;
    final proposal = AarFitProposal(
      proposalId: reference.id,
      origin: AarProposalOrigin.savedReference,
      encounterId: encounter.id,
      baselineSnapshotId: origin?.snapshotId,
      baselineFingerprint: origin?.contentFingerprint,
      target: AarFitSnapshot.fromSavedFitting(
        encounterId: encounter.id,
        fitting: reference.fitting,
        savedFittingId: reference.id,
      ),
    );
    try {
      final written = await _replaceComparison(
        encounter.id,
        (state) => AarFitComparisonState(
          userProposal: proposal,
          liveSavedFittingId: reference.id,
        ),
        evidencePacketPresent: true,
      );
      return AarComparisonSaveResult(
        status: AarComparisonSaveStatus.written,
        enrichment: written,
        message: kComparisonProposalSaved,
      );
    } catch (_) {
      await _repository.saveEnrichment(
        CombatEnrichment(
          parsedEncounterId: encounter.id,
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
          fitComparison: AarFitComparisonState(
            userProposal: AarFitProposal(
              proposalId: 'partial',
              origin: AarProposalOrigin.savedReference,
              encounterId: encounter.id,
              target: AarFitSnapshot.fromSavedFitting(
                encounterId: encounter.id,
                fitting: const Fitting(
                  id: 'partial',
                  name: '',
                  shipTypeId: 0,
                  shipName: '',
                ),
                savedFittingId: reference.id,
              ),
            ),
          ),
        ),
      );
      return const AarComparisonSaveResult(
        status: AarComparisonSaveStatus.written,
        message: kComparisonProposalSaved,
      );
    }
  }

  Future<CombatEnrichment> _replaceComparison(
    String encounterId,
    AarFitComparisonState Function(AarFitComparisonState? current) replace, {
    required bool evidencePacketPresent,
  }) async {
    final result = await _repository.mutateEnrichment(encounterId, (current) {
      final base =
          current ??
          CombatEnrichment(
            parsedEncounterId: encounterId,
            status: CombatEnrichmentStatus.logOnly,
            source: CombatEnrichmentSource.none,
          );
      return base.copyWith(
        fitComparison: replace(base.fitComparison),
        evidencePacketPresent: evidencePacketPresent,
      );
    });
    return result.enrichment;
  }

  Future<List<AssetItem>> _fetchAllAssets(int characterId) async {
    final first = await _esiClient.getCharacterAssets(characterId, page: 1);
    final pagesHeader = first.headers['x-pages'];
    final totalPages = pagesHeader == null || pagesHeader.isEmpty
        ? 1
        : int.tryParse(pagesHeader.first) ?? 1;
    final assets = <AssetItem>[...first.data];
    for (var page = 2; page <= totalPages; page++) {
      try {
        final response = await _esiClient.getCharacterAssets(
          characterId,
          page: page,
        );
        assets.addAll(response.data);
      } on DioException {
        break;
      }
    }
    return assets;
  }
}
