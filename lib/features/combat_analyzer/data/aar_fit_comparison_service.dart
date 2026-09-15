import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/token_manager.dart';
import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import '../../fitting/data/fitting_repository.dart';
import '../../fitting/domain/models.dart';
import '../domain/aar_fit_comparison.dart';
import '../domain/aar_fit_proposal.dart';
import '../domain/aar_fit_snapshot.dart';
import '../domain/combat_enrichment.dart';
import '../domain/parsed_combat_encounter.dart';
import 'aar_comparison_coordinator.dart';
import 'aar_fit_import_parser.dart';
import 'combat_enrichment_repository.dart';
import 'combat_enrichment_service.dart';
import 'current_ship_fit_reader.dart';

const kComparisonCaptureSaved = 'Current fit saved for comparison.';
const kComparisonAuthUnavailable =
    'Sign in with this pilot to capture the current fit.';
const kComparisonNoShip = 'No active ship is available for this pilot.';
const kComparisonCaptureFailure =
    'Could not save the current fit for comparison. Try again.';
const kComparisonProposalSaved = 'Proposed fit saved for comparison.';
const kComparisonProposalFailure =
    'Could not save the proposed fit. Try again.';

const _noExpectation = Object();
final _uuid = Uuid();
const _currentSlot = 'current';
const _proposalSlot = 'userProposal';

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

  @override
  String toString() =>
      'AarComparisonBusyException(encounterId: $encounterId, slot: $slot)';
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

class AarFitComparisonService {
  AarFitComparisonService({
    required CombatEnrichmentRepository repository,
    required CombatEnrichmentService enrichmentService,
    required EsiClient esiClient,
    required AppDatabase database,
    required AarFitImportParser parser,
    required FittingRepository fittingRepository,
    TokenManager? tokenManager,
    CurrentShipFitReader? shipReader,
    AarComparisonCoordinator? coordinator,
    DateTime Function()? clock,
  }) : _repository = repository,
       _enrichmentService = enrichmentService,
       _database = database,
       _parser = parser,
       _fittingRepository = fittingRepository,
       _coordinator = coordinator ?? AarComparisonCoordinator(),
       _shipReader =
           shipReader ??
           CurrentShipFitReader(
             esiClient: esiClient,
             tokenManager: tokenManager ?? TokenManager(database: database),
             clock: clock,
           );

  final CombatEnrichmentRepository _repository;
  final CombatEnrichmentService _enrichmentService;
  final AppDatabase _database;
  final AarFitImportParser _parser;
  final FittingRepository _fittingRepository;
  final AarComparisonCoordinator _coordinator;
  final CurrentShipFitReader _shipReader;

  // Read-only saved-row access stays on the fitting repository; comparison
  // copies never re-query this after snapshot construction.
  FittingRepository get savedFittingRepository => _fittingRepository;

  bool cancelled = false;
  Completer<void>? allowCurrentCommit;
  Completer<void>? allowProposalCommit;

  bool isBusy(String encounterId, {required String slot}) {
    return _coordinator.isBusy(encounterId, slot: slot);
  }

  void cancel() {
    cancelled = true;
  }

  void dispose() {
    Log.d('AAR', 'comparison service disposed; in-flight commits continue');
  }

  CombatEnrichment? projectEvidence(CombatEnrichment? raw) {
    if (raw == null) return null;
    if (raw.evidencePacketPresent) return raw;
    final hasEvidence =
        raw.pilotFitEvidence != null ||
        raw.victimFitEvidence != null ||
        raw.killmailId != null ||
        !raw.evidenceLedger.isEmpty ||
        raw.killmailSearchCompleted;
    if (hasEvidence) return raw;
    return null;
  }

  Future<List<AssetCacheData>> eligibleCachedAssets(
    ParsedCombatEncounter encounter,
  ) {
    final characterId = encounter.characterId;
    if (characterId == null) return Future.value(const []);
    return (_database.select(
      _database.assetCache,
    )..where((row) => row.characterId.equals(characterId))).get();
  }

  Future<List<SavedFittingReference>> listSavedReferences({
    required int? characterId,
  }) async {
    final query = _database.select(_database.savedFittings);
    if (characterId != null) {
      query.where(
        (row) => row.characterId.equals(characterId) | row.characterId.isNull(),
      );
    } else {
      query.where((row) => row.characterId.isNull());
    }
    final records = await query.get();
    return [
      for (final record in records)
        SavedFittingReference(
          id: record.id,
          fitting: Fitting.fromJson(
            Map<String, dynamic>.from(jsonDecode(record.fittingJson) as Map),
          ),
          characterId: record.characterId,
          createdAt: record.createdAt,
          updatedAt: record.updatedAt,
        ),
    ];
  }

  Future<CombatEnrichment?> load(String encounterId) {
    return _enrichmentService.loadEnrichment(encounterId);
  }

  Future<AarComparisonSaveResult> captureCurrentForComparison(
    ParsedCombatEncounter encounter, {
    Object? expectedCurrentSnapshotId = _noExpectation,
  }) {
    _reserve(encounter.id, _currentSlot);
    return _captureCurrentForComparison(
      encounter,
      expectedCurrentSnapshotId: expectedCurrentSnapshotId,
    );
  }

  Future<AarComparisonSaveResult> importProposal(
    ParsedCombatEncounter encounter,
    String text, {
    Object? expectedUserProposalId = _noExpectation,
    AarFitSnapshot? origin,
  }) {
    _reserve(encounter.id, _proposalSlot);
    return _importProposal(
      encounter,
      text,
      expectedUserProposalId: expectedUserProposalId,
      origin: origin,
    );
  }

  Future<AarComparisonSaveResult> copySavedReference(
    ParsedCombatEncounter encounter,
    SavedFittingReference reference, {
    Object? expectedUserProposalId = _noExpectation,
    AarFitSnapshot? origin,
  }) {
    _reserve(encounter.id, _proposalSlot);
    return _copySavedReference(
      encounter,
      reference,
      expectedUserProposalId: expectedUserProposalId,
      origin: origin,
    );
  }

  Future<AarComparisonSaveResult> _captureCurrentForComparison(
    ParsedCombatEncounter encounter, {
    required Object? expectedCurrentSnapshotId,
  }) async {
    try {
      final read = await _shipReader.read(encounter);
      final snapshot = AarFitSnapshot.fromCurrentCapture(
        encounterId: encounter.id,
        fitting: read.fitting,
        characterId: read.characterId,
        recordedAt: read.capturedAt,
        sourceItemIds: read.sourceItemIds,
        snapshotId: _uuid.v4(),
        knowledge: read.knowledge,
        limitations: read.limitations,
      );
      return await _commitOwnedSlot(
        encounterId: encounter.id,
        successMessage: kComparisonCaptureSaved,
        persistFailureMessage: kComparisonCaptureFailure,
        allowCommit: allowCurrentCommit,
        checkCurrentSnapshotId: _shouldCheck(expectedCurrentSnapshotId),
        expectedCurrentSnapshotId: _expectedId(expectedCurrentSnapshotId),
        transform: (current) {
          final base = _baseForComparisonWrite(encounter.id, current);
          return base.copyWith(
            fitComparison: (base.fitComparison ?? const AarFitComparisonState())
                .withCurrentSnapshot(snapshot),
          );
        },
      );
    } on CurrentShipFitReadException catch (error) {
      return _captureFailure(error.kind);
    } catch (error, stack) {
      Log.e('AAR', 'comparison capture failed', error, stack);
      return const AarComparisonSaveResult(
        status: AarComparisonSaveStatus.failed,
        code: AarComparisonFailureCode.captureFailure,
        message: kComparisonCaptureFailure,
      );
    } finally {
      _coordinator.settle(encounter.id, slot: _currentSlot);
    }
  }

  Future<AarComparisonSaveResult> _importProposal(
    ParsedCombatEncounter encounter,
    String text, {
    required Object? expectedUserProposalId,
    AarFitSnapshot? origin,
  }) async {
    try {
      if (_consumeCancel()) {
        return const AarComparisonSaveResult(
          status: AarComparisonSaveStatus.cancelled,
          code: AarComparisonFailureCode.cancelled,
        );
      }
      final parsed = await _parser.parseWithKnowledge(text);
      final proposal = AarFitProposal(
        proposalId: _uuid.v4(),
        origin: AarProposalOrigin.importedReference,
        encounterId: encounter.id,
        baselineSnapshotId: origin?.snapshotId,
        baselineFingerprint: origin?.contentFingerprint,
        target: AarFitSnapshot.fromEftImport(
          encounterId: encounter.id,
          fitting: parsed.fitting,
          snapshotId: _uuid.v4(),
          knowledge: parsed.knowledge,
        ),
      );
      return await _commitOwnedSlot(
        encounterId: encounter.id,
        successMessage: kComparisonProposalSaved,
        persistFailureMessage: kComparisonProposalFailure,
        allowCommit: allowProposalCommit,
        checkUserProposalId: _shouldCheck(expectedUserProposalId),
        expectedUserProposalId: _expectedId(expectedUserProposalId),
        transform: (current) {
          final base = _baseForComparisonWrite(encounter.id, current);
          return base.copyWith(
            fitComparison: (base.fitComparison ?? const AarFitComparisonState())
                .withUserProposal(proposal),
          );
        },
      );
    } on AarFitImportException catch (error, stack) {
      Log.e('AAR', 'comparison proposal import rejected', error, stack);
      return const AarComparisonSaveResult(
        status: AarComparisonSaveStatus.rejected,
        code: AarComparisonFailureCode.invalidProposal,
        message: kComparisonProposalFailure,
      );
    } catch (error, stack) {
      Log.e('AAR', 'comparison proposal import failed', error, stack);
      return const AarComparisonSaveResult(
        status: AarComparisonSaveStatus.failed,
        code: AarComparisonFailureCode.persistenceFailure,
        message: kComparisonProposalFailure,
      );
    } finally {
      cancelled = false;
      _coordinator.settle(encounter.id, slot: _proposalSlot);
    }
  }

  Future<AarComparisonSaveResult> _copySavedReference(
    ParsedCombatEncounter encounter,
    SavedFittingReference reference, {
    required Object? expectedUserProposalId,
    AarFitSnapshot? origin,
  }) async {
    try {
      if (_consumeCancel()) {
        return const AarComparisonSaveResult(
          status: AarComparisonSaveStatus.cancelled,
          code: AarComparisonFailureCode.cancelled,
        );
      }
      final copied = Fitting(
        id: reference.fitting.id,
        name: reference.fitting.name,
        description: reference.fitting.description,
        shipTypeId: reference.fitting.shipTypeId,
        shipName: reference.fitting.shipName,
        highSlots: List<FittedModule>.from(reference.fitting.highSlots),
        medSlots: List<FittedModule>.from(reference.fitting.medSlots),
        lowSlots: List<FittedModule>.from(reference.fitting.lowSlots),
        rigSlots: List<FittedModule>.from(reference.fitting.rigSlots),
        subsystems: List<FittedModule>.from(reference.fitting.subsystems),
        drones: List<DroneGroup>.from(reference.fitting.drones),
        fighters: List<FighterGroup>.from(reference.fitting.fighters),
        cargo: List<CargoItem>.from(reference.fitting.cargo),
      );
      final proposal = AarFitProposal(
        proposalId: reference.id,
        origin: AarProposalOrigin.savedReference,
        encounterId: encounter.id,
        baselineSnapshotId: origin?.snapshotId,
        baselineFingerprint: origin?.contentFingerprint,
        target: AarFitSnapshot.fromSavedFitting(
          encounterId: encounter.id,
          fitting: copied,
          savedFittingId: reference.id,
        ),
      );
      return await _commitOwnedSlot(
        encounterId: encounter.id,
        successMessage: kComparisonProposalSaved,
        persistFailureMessage: kComparisonProposalFailure,
        allowCommit: allowProposalCommit,
        checkUserProposalId: _shouldCheck(expectedUserProposalId),
        expectedUserProposalId: _expectedId(expectedUserProposalId),
        transform: (current) {
          final base = _baseForComparisonWrite(encounter.id, current);
          return base.copyWith(
            fitComparison: (base.fitComparison ?? const AarFitComparisonState())
                .withUserProposal(proposal),
          );
        },
      );
    } catch (error, stack) {
      Log.e('AAR', 'comparison saved-copy failed', error, stack);
      return const AarComparisonSaveResult(
        status: AarComparisonSaveStatus.failed,
        code: AarComparisonFailureCode.persistenceFailure,
        message: kComparisonProposalFailure,
      );
    } finally {
      cancelled = false;
      _coordinator.settle(encounter.id, slot: _proposalSlot);
    }
  }

  Future<AarComparisonSaveResult> _commitOwnedSlot({
    required String encounterId,
    required String successMessage,
    required String persistFailureMessage,
    required CombatEnrichment Function(CombatEnrichment? current) transform,
    Completer<void>? allowCommit,
    bool checkCurrentSnapshotId = false,
    String? expectedCurrentSnapshotId,
    bool checkUserProposalId = false,
    String? expectedUserProposalId,
  }) async {
    await allowCommit?.future;
    if (_consumeCancel()) {
      return const AarComparisonSaveResult(
        status: AarComparisonSaveStatus.cancelled,
        code: AarComparisonFailureCode.cancelled,
      );
    }
    try {
      final result = await _repository.mutateEnrichment(
        encounterId,
        transform,
        checkCurrentSnapshotId: checkCurrentSnapshotId,
        expectedCurrentSnapshotId: expectedCurrentSnapshotId,
        checkUserProposalId: checkUserProposalId,
        expectedUserProposalId: expectedUserProposalId,
      );
      if (result.status == EnrichmentMutationStatus.preconditionFailed) {
        Log.i('AAR', 'comparison slot conflict encounter=$encounterId');
        return AarComparisonSaveResult(
          status: AarComparisonSaveStatus.conflict,
          enrichment: result.enrichment,
        );
      }
      return AarComparisonSaveResult(
        status: result.status == EnrichmentMutationStatus.unchanged
            ? AarComparisonSaveStatus.unchanged
            : AarComparisonSaveStatus.written,
        enrichment: result.enrichment,
        message: successMessage,
      );
    } catch (error, stack) {
      Log.e('AAR', 'comparison persist failed', error, stack);
      return AarComparisonSaveResult(
        status: AarComparisonSaveStatus.failed,
        code: AarComparisonFailureCode.persistenceFailure,
        message: persistFailureMessage,
      );
    }
  }

  CombatEnrichment _baseForComparisonWrite(
    String encounterId,
    CombatEnrichment? current,
  ) {
    return current ??
        CombatEnrichment(
          parsedEncounterId: encounterId,
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
          evidencePacketPresent: false,
        );
  }

  void _reserve(String encounterId, String slot) {
    try {
      _coordinator.reserve(encounterId, slot: slot);
    } on StateError {
      throw AarComparisonBusyException(encounterId, slot);
    }
  }

  bool _consumeCancel() {
    if (!cancelled) return false;
    cancelled = false;
    return true;
  }

  bool _shouldCheck(Object? expected) => !identical(expected, _noExpectation);

  String? _expectedId(Object? expected) {
    if (identical(expected, _noExpectation)) return null;
    return expected as String?;
  }

  AarComparisonSaveResult _captureFailure(CurrentShipFitReadFailure kind) {
    return switch (kind) {
      CurrentShipFitReadFailure.authUnavailable =>
        const AarComparisonSaveResult(
          status: AarComparisonSaveStatus.failed,
          code: AarComparisonFailureCode.authUnavailable,
          message: kComparisonAuthUnavailable,
        ),
      CurrentShipFitReadFailure.noShip => const AarComparisonSaveResult(
        status: AarComparisonSaveStatus.failed,
        code: AarComparisonFailureCode.noShip,
        message: kComparisonNoShip,
      ),
      CurrentShipFitReadFailure.captureFailure => const AarComparisonSaveResult(
        status: AarComparisonSaveStatus.failed,
        code: AarComparisonFailureCode.captureFailure,
        message: kComparisonCaptureFailure,
      ),
    };
  }
}
