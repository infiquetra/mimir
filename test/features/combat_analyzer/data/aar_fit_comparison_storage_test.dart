// W1 RED contracts for owned comparison storage and source acquisition.
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §3 / §4.4:
// - P01: capture overwrites pilotFitEvidence; each save replaces the
//   whole fitComparison object; _copy/_mergeRefresh drop comparison
//   on re-analysis; toPromptJson leaks comparison JSON.
// - P03: reversed commits wipe the other owned slot.
// - P04: no comparison-slot busy lock; snapshot IDs are not unique per
//   replacement; no field-scoped CAS; dispose aborts an in-flight save.
// - P06: saved copies rebind a live row id; alternative copies union
//   previous high slots.
// - P08: invalid EFT still writes type-id-0; cancel is ignored; SQL
//   failure writes a partial replacement.
// - P09: missing ship / auth / page failure still save; empty inventory
//   is recordedComplete rather than hull-only.
// - P11: capture uses the globally active character; cache eligibility
//   is not encounter-pilot scoped.
// - First-row: comparison-only insert sets evidencePacketPresent true
//   and projectEvidence returns the raw row.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/auth/oauth_service.dart';
import 'package:mimir/core/auth/token_manager.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/combat_analyzer/data/aar_fit_comparison_service.dart';
import 'package:mimir/features/combat_analyzer/data/aar_fit_import_parser.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_killmail_discovery_client.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_assessment.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_scorer.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_comparison.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_proposal.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_snapshot.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/fitting/data/fitting_repository.dart';
import 'package:mimir/features/fitting/domain/models.dart';

import '../fixtures/aar_evidence_fixtures.dart';
import '../fixtures/aar_fit_import_fixtures.dart';
import '../fixtures/fit_evidence_harness.dart';

void main() {
  group('W1 comparison storage', () {
    late FitEvidenceHarness harness;
    late AarFitComparisonService service;
    late FittingRepository fittings;

    setUp(() async {
      harness = FitEvidenceHarness();
      await harness.setUp();
      fittings = FittingRepository(harness.appDb);
      service = _service(harness, fittings);
    });

    tearDown(() async {
      await harness.tearDown();
    });

    test(
      'P01 independent persistence survives reload and re-analysis',
      () async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        final seeded = await harness.seedUnrelatedEnrichment(encounter);
        const editor = Fitting(
          id: 'editor-fit',
          name: 'Editor',
          shipTypeId: 587,
          shipName: 'Rifter',
          highSlots: [
            FittedModule(
              typeId: 484,
              typeName: '125mm Gatling AutoCannon II',
              slotType: SlotType.high,
              slotIndex: 0,
            ),
          ],
        );
        await fittings.saveFitting(
          editor,
          characterId: FitEvidenceHarness.characterAId,
        );
        final beforePilot = jsonEncode(seeded.pilotFitEvidence!.toJson());
        final beforeVictim = jsonEncode(seeded.victimFitEvidence!.toJson());
        final beforeLedger = jsonEncode(seeded.evidenceLedger.toJson());
        final beforeScore = _score(encounter, seeded).score;

        harness.scriptFittedCapture();
        final captured = await service.captureCurrentForComparison(encounter);
        final proposed = await service.importProposal(
          encounter,
          kAarSupportedEft,
        );
        expect(captured.isSuccess, isTrue);
        expect(proposed.isSuccess, isTrue);

        Future<void> expectIsolated(
          CombatEnrichment? row, {
          required String why,
        }) async {
          expect(row, isNotNull, reason: why);
          expect(row!.fitComparison?.currentSnapshot, isNotNull, reason: why);
          expect(row.fitComparison?.userProposal, isNotNull, reason: why);
          expect(
            jsonEncode(row.pilotFitEvidence!.toJson()),
            beforePilot,
            reason: why,
          );
          expect(
            jsonEncode(row.victimFitEvidence!.toJson()),
            beforeVictim,
            reason: why,
          );
          expect(
            jsonEncode(row.evidenceLedger.toJson()),
            beforeLedger,
            reason: why,
          );
          expect(
            _score(encounter, service.projectEvidence(row)).score,
            beforeScore,
            reason: why,
          );
          expect(row.toPromptJson().containsKey('fitComparison'), isFalse);
          final stillEditor = await fittings.getFittings(
            characterId: FitEvidenceHarness.characterAId,
          );
          expect(
            stillEditor.singleWhere((fit) => fit.id == 'editor-fit').highSlots,
            hasLength(1),
          );
        }

        await expectIsolated(
          proposed.enrichment,
          why: 'in-memory after both saves',
        );
        final reloaded = await harness.repository.loadEnrichment(encounter.id);
        await expectIsolated(reloaded, why: 'SQL reload');

        await harness.enrichmentService.attachDerivedEvidence(
          reloaded!,
          const AarDerivationBundle.empty(),
          encounterId: encounter.id,
        );
        final afterAnalyze = await harness.repository.loadEnrichment(
          encounter.id,
        );
        await expectIsolated(afterAnalyze, why: 'after re-analysis merge');
      },
    );

    test('P03 reversed completion preserves both slots and victim', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      final seeded = await harness.seedUnrelatedEnrichment(encounter);
      harness.scriptFittedCapture();
      service.allowCurrentCommit = Completer<void>();
      service.allowProposalCommit = Completer<void>();

      final capture = service.captureCurrentForComparison(encounter);
      final proposal = service.importProposal(encounter, kAarSupportedEft);
      service.allowProposalCommit!.complete();
      await proposal;
      service.allowCurrentCommit!.complete();
      await capture;

      final loaded = await harness.repository.loadEnrichment(encounter.id);
      expect(loaded?.fitComparison?.currentSnapshot, isNotNull);
      expect(loaded?.fitComparison?.userProposal, isNotNull);
      expect(loaded?.victimCharacterId, seeded.victimCharacterId);
      expect(
        jsonEncode(loaded!.victimFitEvidence!.toJson()),
        jsonEncode(seeded.victimFitEvidence!.toJson()),
      );
    });

    test('P04 duplicate capture is busy-rejected and ids are unique', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.seedUnrelatedEnrichment(encounter);
      final delay = Completer<void>();
      harness.scriptFittedCapture(delayShip: delay.future);
      final first = service.captureCurrentForComparison(encounter);
      await Future<void>.delayed(Duration.zero);
      expect(service.isBusy(encounter.id, slot: 'current'), isTrue);
      expect(
        () => service.captureCurrentForComparison(encounter),
        throwsA(isA<AarComparisonBusyException>()),
      );
      delay.complete();
      await first;

      harness.esiAdapter.clearScripts();
      harness.scriptFittedCapture();
      await service.captureCurrentForComparison(encounter);
      final firstId = (await harness.repository.loadEnrichment(
        encounter.id,
      ))!.fitComparison!.currentSnapshot!.snapshotId;
      harness.esiAdapter.clearScripts();
      harness.scriptFittedCapture();
      await service.captureCurrentForComparison(encounter);
      final again = await harness.repository.loadEnrichment(encounter.id);
      expect(again!.fitComparison!.currentSnapshot!.snapshotId, isNot(firstId));
    });

    test(
      'P04 dispose during save still commits the original encounter',
      () async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        await harness.seedUnrelatedEnrichment(encounter);
        final delay = Completer<void>();
        harness.scriptFittedCapture(delayShip: delay.future);
        final pending = service.captureCurrentForComparison(encounter);
        service.dispose();
        delay.complete();
        final result = await pending;
        expect(result.isSuccess, isTrue);
        final loaded = await harness.repository.loadEnrichment(encounter.id);
        expect(loaded?.fitComparison?.currentSnapshot, isNotNull);
      },
    );

    test('P06 saved copy is isolated from later original edits', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.seedUnrelatedEnrichment(encounter);
      const original = Fitting(
        id: 'doctrine-a',
        name: 'Doctrine A',
        shipTypeId: 587,
        shipName: 'Rifter',
        highSlots: [
          FittedModule(
            typeId: 2048,
            typeName: 'Damage Control II',
            slotType: SlotType.high,
            slotIndex: 0,
          ),
        ],
      );
      await fittings.saveFitting(
        original,
        characterId: FitEvidenceHarness.characterAId,
      );
      final copied = await service.copySavedReference(
        encounter,
        SavedFittingReference(
          id: original.id,
          fitting: original,
          characterId: FitEvidenceHarness.characterAId,
          createdAt: FitEvidenceHarness.defaultClock(),
          updatedAt: FitEvidenceHarness.defaultClock(),
        ),
      );
      expect(copied.isSuccess, isTrue);

      await fittings.saveFitting(
        original.copyWith(
          highSlots: [
            ...original.highSlots,
            const FittedModule(
              typeId: 484,
              typeName: '125mm Gatling AutoCannon II',
              slotType: SlotType.high,
              slotIndex: 1,
            ),
          ],
        ),
        characterId: FitEvidenceHarness.characterAId,
      );

      final sql = await harness.repository.loadEnrichment(encounter.id);
      expect(
        sql?.fitComparison?.userProposal?.target?.fitting.highSlots,
        hasLength(1),
      );
      final viaService = await service.load(encounter.id);
      expect(
        viaService?.fitComparison?.userProposal?.target?.fitting.highSlots,
        hasLength(1),
      );

      const alt = Fitting(
        id: 'doctrine-b',
        name: 'Doctrine B',
        shipTypeId: 587,
        shipName: 'Rifter',
        highSlots: [
          FittedModule(
            typeId: 5973,
            typeName: '1MN Afterburner II',
            slotType: SlotType.high,
            slotIndex: 0,
          ),
        ],
      );
      await fittings.saveFitting(
        alt,
        characterId: FitEvidenceHarness.characterAId,
      );
      await service.copySavedReference(
        encounter,
        SavedFittingReference(
          id: alt.id,
          fitting: alt,
          characterId: FitEvidenceHarness.characterAId,
          createdAt: FitEvidenceHarness.defaultClock(),
          updatedAt: FitEvidenceHarness.defaultClock(),
        ),
      );
      final switched = await harness.repository.loadEnrichment(encounter.id);
      final highs =
          switched?.fitComparison?.userProposal?.target?.fitting.highSlots ??
          const <FittedModule>[];
      expect(highs.map((module) => module.typeId), [5973]);
    });

    test(
      'P08 invalid, cancel, and SQL failure retain the prior proposal',
      () async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        final seeded = await harness.seedUnrelatedEnrichment(encounter);
        const priorFit = Fitting(
          id: 'prior-prop',
          name: 'Prior',
          shipTypeId: 587,
          shipName: 'Rifter',
        );
        await harness.repository.saveEnrichment(
          seeded.copyWith(
            fitComparison: AarFitComparisonState(
              userProposal: AarFitProposal(
                proposalId: priorFit.id,
                origin: AarProposalOrigin.savedReference,
                encounterId: encounter.id,
                target: AarFitSnapshot.fromSavedFitting(
                  encounterId: encounter.id,
                  fitting: priorFit,
                  savedFittingId: priorFit.id,
                ),
              ),
            ),
          ),
        );
        const priorId = 'prior-prop';

        final invalid = await service.importProposal(
          encounter,
          kAarBrokenHeaderEft,
        );
        expect(invalid.isSuccess, isFalse);
        expect(invalid.code, AarComparisonFailureCode.invalidProposal);
        var loaded = await harness.repository.loadEnrichment(encounter.id);
        expect(loaded!.fitComparison!.userProposal!.proposalId, priorId);
        expect(
          loaded.fitComparison!.userProposal!.target!.fitting.shipTypeId,
          isNot(0),
        );

        service.cancel();
        final cancelled = await service.importProposal(
          encounter,
          kAarSupportedEft,
        );
        expect(cancelled.status, AarComparisonSaveStatus.cancelled);
        loaded = await harness.repository.loadEnrichment(encounter.id);
        expect(loaded!.fitComparison!.userProposal!.proposalId, priorId);

        await harness.appDb.customStatement('''
CREATE TRIGGER abort_w1_proposal
BEFORE UPDATE ON combat_encounter_enrichments
WHEN NEW.parsed_encounter_id = '${encounter.id}'
BEGIN
  SELECT RAISE(ABORT, 'sql boom');
END;
''');
        final failed = await service.copySavedReference(
          encounter,
          SavedFittingReference(
            id: 'boom',
            fitting: priorFit,
            characterId: FitEvidenceHarness.characterAId,
            createdAt: FitEvidenceHarness.defaultClock(),
            updatedAt: FitEvidenceHarness.defaultClock(),
          ),
        );
        expect(failed.isSuccess, isFalse);
        expect(failed.code, AarComparisonFailureCode.persistenceFailure);
        loaded = await CombatEnrichmentRepository(
          database: harness.appDb,
        ).loadEnrichment(encounter.id);
        expect(loaded!.fitComparison!.userProposal!.proposalId, priorId);
        expect(
          loaded.fitComparison!.userProposal!.target!.fitting.shipTypeId,
          isNot(0),
        );
        await harness.appDb.customStatement(
          'DROP TRIGGER IF EXISTS abort_w1_proposal',
        );
      },
    );

    test('P09 authenticated success does not mutate evidence', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      final seeded = await harness.seedUnrelatedEnrichment(encounter);
      final priorPilot = jsonEncode(seeded.pilotFitEvidence!.toJson());
      harness.scriptFittedCapture();
      final success = await service.captureCurrentForComparison(encounter);
      expect(success.isSuccess, isTrue);
      expect(success.message, kComparisonCaptureSaved);
      final loaded = await harness.repository.loadEnrichment(encounter.id);
      expect(loaded!.fitComparison!.currentSnapshot, isNotNull);
      expect(jsonEncode(loaded.pilotFitEvidence!.toJson()), priorPilot);
    });

    test('P09 no authentication retains the prior snapshot', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      final priorId = await _seedPriorSnapshot(harness, encounter);
      await harness.tokenManager.deleteTokens(FitEvidenceHarness.characterAId);
      final noAuth = await service.captureCurrentForComparison(encounter);
      expect(noAuth.isSuccess, isFalse);
      expect(noAuth.code, AarComparisonFailureCode.authUnavailable);
      expect(noAuth.message, kComparisonAuthUnavailable);
      final loaded = await harness.repository.loadEnrichment(encounter.id);
      expect(loaded!.fitComparison!.currentSnapshot!.snapshotId, priorId);
    });

    test('P09 missing ship retains the prior snapshot', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      final priorId = await _seedPriorSnapshot(harness, encounter);
      harness.scriptCharacterShip(statusCode: 404);
      final missing = await service.captureCurrentForComparison(encounter);
      expect(missing.isSuccess, isFalse);
      expect(missing.code, AarComparisonFailureCode.noShip);
      expect(missing.message, kComparisonNoShip);
      final loaded = await harness.repository.loadEnrichment(encounter.id);
      expect(loaded!.fitComparison!.currentSnapshot!.snapshotId, priorId);
    });

    test('P09 middle asset page failure retains the prior snapshot', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      final priorId = await _seedPriorSnapshot(harness, encounter);
      harness.scriptCharacterShip();
      harness.scriptAssetPage(
        characterId: FitEvidenceHarness.characterAId,
        page: 1,
        body: aarFittedPage1(),
        totalPages: 2,
      );
      harness.scriptAssetPage(
        characterId: FitEvidenceHarness.characterAId,
        page: 2,
        body: const <Map<String, dynamic>>[],
        statusCode: 500,
        totalPages: 2,
      );
      final failed = await service.captureCurrentForComparison(encounter);
      expect(failed.isSuccess, isFalse);
      expect(failed.code, AarComparisonFailureCode.captureFailure);
      expect(failed.message, kComparisonCaptureFailure);
      final loaded = await harness.repository.loadEnrichment(encounter.id);
      expect(loaded!.fitComparison!.currentSnapshot!.snapshotId, priorId);
    });

    test('P09 empty inventory is a qualified hull-only snapshot', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.seedUnrelatedEnrichment(encounter);
      harness.scriptFittedCapture(emptyInventory: true);
      final empty = await service.captureCurrentForComparison(encounter);
      expect(empty.isSuccess, isTrue);
      final snapshot = empty.enrichment!.fitComparison!.currentSnapshot!;
      expect(snapshot.fitting.shipTypeId, 587);
      expect(snapshot.fitting.allModules, isEmpty);
      expect(
        snapshot.knowledge.group(FitInventoryGroup.high).completeness,
        isNot(InventoryCompleteness.recordedComplete),
      );
      expect(snapshot.limitations, isNotEmpty);
    });

    test('P11 capture and cache stay scoped to encounter pilot P', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.seedUnrelatedEnrichment(encounter);
      await harness.activateCharacter(FitEvidenceHarness.characterBId);
      await harness.appDb
          .into(harness.appDb.assetCache)
          .insert(
            AssetCacheCompanion.insert(
              itemId: const Value(88001),
              characterId: FitEvidenceHarness.characterBId,
              typeId: 2048,
              quantity: 3,
              locationId: 60003760,
              lastUpdated: harness.clock(),
            ),
          );
      harness.scriptFittedCapture(characterId: FitEvidenceHarness.characterAId);
      harness.scriptFittedCapture(
        characterId: FitEvidenceHarness.characterBId,
        shipTypeId: 9020,
        shipName: 'UniqueShip',
        shipTypeName: 'UniqueShip',
      );
      final captured = await service.captureCurrentForComparison(encounter);
      expect(captured.isSuccess, isTrue);
      final snapshot = captured.enrichment!.fitComparison!.currentSnapshot!;
      expect(snapshot.subject.characterId, FitEvidenceHarness.characterAId);
      expect(snapshot.fitting.shipTypeId, 587);
      final shipPaths = [
        for (final request in harness.esiAdapter.requests) request.uri.path,
      ];
      expect(
        shipPaths.any(
          (path) => path.contains(
            '/characters/${FitEvidenceHarness.characterBId}/ship',
          ),
        ),
        isFalse,
      );
      final eligible = await service.eligibleCachedAssets(encounter);
      expect(
        eligible.every(
          (asset) => asset.characterId == FitEvidenceHarness.characterAId,
        ),
        isTrue,
      );
    });

    test(
      'first comparison save on a no-character row leaves evidence identical',
      () async {
        final encounter = encounterWith(characterId: null);
        expect(await harness.repository.loadEnrichment(encounter.id), isNull);
        final before = _score(encounter, null);
        final saved = await service.importProposal(encounter, kAarSupportedEft);
        expect(saved.isSuccess, isTrue);
        final raw = await harness.repository.loadEnrichment(encounter.id);
        expect(raw, isNotNull);
        expect(raw!.evidencePacketPresent, isFalse);
        expect(service.projectEvidence(raw), isNull);
        expect(raw.evidenceLedger.isEmpty, isTrue);
        expect(raw.pilotFitEvidence, isNull);
        expect(raw.killmailSearchCompleted, isFalse);
        final after = _score(encounter, service.projectEvidence(raw));
        expect(after.score, before.score);
        expect(
          after.dimensions.map((row) => row.status),
          before.dimensions.map((row) => row.status),
        );
      },
    );
  });

  group('W1 two-connection CAS', () {
    test(
      'P04 stale slot expectation cannot overwrite the other connection',
      () async {
        final dir = await Directory.systemTemp.createTemp('mimir-w1-cas-');
        final file = File('${dir.path}/app.sqlite');
        final db1 = AppDatabase.forTesting(NativeDatabase(file));
        final sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() async {
          await db1.close();
          await sdeDb.close();
          if (dir.existsSync()) await dir.delete(recursive: true);
        });
        await db1.customSelect('SELECT 1').get();
        final db2 = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(db2.close);
        final sde = SdeService(database: sdeDb);

        const encounterId = 'enc-cas';
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        ).copyWith(id: encounterId);
        final repo1 = CombatEnrichmentRepository(database: db1);
        final repo2 = CombatEnrichmentRepository(database: db2);
        final svc1 = _fileService(db1, repo1, sde: sde);
        final svc2 = _fileService(db2, repo2, sde: sde);
        const fitA = Fitting(
          id: 'a',
          name: 'A',
          shipTypeId: 587,
          shipName: 'Rifter',
        );
        const fitB = Fitting(
          id: 'b',
          name: 'B',
          shipTypeId: 9020,
          shipName: 'UniqueShip',
        );
        final second = await svc2.copySavedReference(
          encounter,
          SavedFittingReference(
            id: fitB.id,
            fitting: fitB,
            createdAt: FitEvidenceHarness.defaultClock(),
            updatedAt: FitEvidenceHarness.defaultClock(),
          ),
          expectedUserProposalId: null,
        );
        expect(second.isSuccess, isTrue);
        final stale = await svc1.copySavedReference(
          encounter,
          SavedFittingReference(
            id: fitA.id,
            fitting: fitA,
            createdAt: FitEvidenceHarness.defaultClock(),
            updatedAt: FitEvidenceHarness.defaultClock(),
          ),
          expectedUserProposalId: null,
        );
        expect(stale.status, AarComparisonSaveStatus.conflict);
        final loaded = await repo2.loadEnrichment(encounterId);
        expect(loaded!.fitComparison!.userProposal!.proposalId, 'b');
        expect(
          loaded.fitComparison!.userProposal!.target!.fitting.shipTypeId,
          9020,
        );
      },
    );
  });
}

AarFitComparisonService _service(
  FitEvidenceHarness harness,
  FittingRepository fittings,
) {
  return AarFitComparisonService(
    repository: harness.repository,
    enrichmentService: harness.enrichmentService,
    esiClient: harness.esiClient,
    database: harness.appDb,
    parser: AarFitImportParser(sdeService: harness.sdeService),
    fittingRepository: fittings,
  );
}

AarFitComparisonService _fileService(
  AppDatabase database,
  CombatEnrichmentRepository repository, {
  required SdeService sde,
}) {
  final oauth = OAuthService();
  final tokens = TokenManager(database: database);
  final esi = EsiClient(
    tokenManager: tokens,
    oauthService: oauth,
    database: database,
  );
  addTearDown(esi.dispose);
  return AarFitComparisonService(
    repository: repository,
    enrichmentService: CombatEnrichmentService(
      repository: repository,
      esiClient: esi,
      discoveryClient: CombatKillmailDiscoveryClient(),
      tokenManager: tokens,
      oauthService: oauth,
      sdeService: sde,
    ),
    esiClient: esi,
    database: database,
    parser: AarFitImportParser(sdeService: sde),
    fittingRepository: FittingRepository(database),
  );
}

Future<String> _seedPriorSnapshot(
  FitEvidenceHarness harness,
  ParsedCombatEncounter encounter,
) async {
  final seeded = await harness.seedUnrelatedEnrichment(encounter);
  final prior = AarFitSnapshot.fromCurrentCapture(
    encounterId: encounter.id,
    fitting: seeded.pilotFitEvidence!.fitting,
    characterId: FitEvidenceHarness.characterAId,
  );
  await harness.repository.saveEnrichment(
    seeded.copyWith(
      fitComparison: AarFitComparisonState(currentSnapshot: prior),
    ),
  );
  return prior.snapshotId;
}

AarEvidenceAssessment _score(
  ParsedCombatEncounter encounter,
  CombatEnrichment? enrichment,
) {
  return const AarEvidenceScorer().assess(
    AarEvidenceInputs(
      encounter: encounter,
      enrichment: enrichment,
      bundle: const AarDerivationBundle.empty(),
      incoming: profile(profiled: 0),
      outgoing: profile(profiled: 0),
    ),
  );
}
