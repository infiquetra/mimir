import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/data/codex_analysis_client.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_aar_report.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/fitting/domain/models.dart';
import 'package:mimir/features/combat_analyzer/presentation/analysis_multipane_screen.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_evidence_checklist_card.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_pre_analysis_gate.dart';

import '../fixtures/aar_evidence_fixtures.dart';
import '../fixtures/aar_fit_import_fixtures.dart';
import '../fixtures/fit_evidence_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FitEvidenceHarness harness;

  setUp(() async {
    harness = FitEvidenceHarness();
    await harness.setUp();
  });

  tearDown(() async {
    await harness.tearDown();
  });

  final importFit = find.byKey(
    const Key('aar-evidence-action-importFit-pilotFit'),
  );
  final useCurrentFit = find.byKey(
    const Key('aar-evidence-action-useCurrentFit-pilotFit'),
  );

  testWidgets(
    'U0 Import Fit and Use Current Fit are reachable in pre-analysis',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.pumpScreen(tester, encounter: encounter);
      await harness.waitFor(tester, importFit);
      expect(find.byType(AnalysisMultiPaneScreen), findsOneWidget);
      expect(find.byType(AarEvidenceChecklistCard), findsWidgets);
      expect(find.byType(AarPreAnalysisGate), findsOneWidget);
      expect(importFit, findsOneWidget);
      expect(useCurrentFit, findsOneWidget);
      expect(harness.esiAdapter.requests, isEmpty);
      expect(harness.codex.calls, 0);
      expect(harness.discovery.fetches, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U0 Import Fit and Use Current Fit are reachable on a cached AAR',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.seedCachedReport(encounter);
      await harness.pumpScreen(tester, encounter: encounter);
      await harness.waitFor(tester, importFit);
      expect(find.byType(AnalysisMultiPaneScreen), findsOneWidget);
      expect(importFit, findsOneWidget);
      expect(useCurrentFit, findsOneWidget);
      expect(find.text('Import Pilot Fit'), findsNothing);
      expect(harness.esiAdapter.requests, isEmpty);
      expect(harness.codex.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U0 imported EFT round-trips through real SQL without score stubs',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      final saved = await harness.enrichmentService.importPilotFit(
        encounter,
        '[Rifter, Test]\n',
      );
      expect(saved.pilotFitEvidence, isNotNull);
      expect(saved.pilotFitEvidence!.fitting.shipTypeId, 587);
      expect(saved.pilotFitEvidence!.source, EvidenceSource.manualFitImport);
      expect(saved.pilotFitEvidence!.confidence, EvidenceConfidence.confirmed);

      final reloaded = await CombatEnrichmentRepository(
        database: harness.appDb,
      ).loadEnrichment(encounter.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.pilotFitEvidence, isNotNull);
      expect(reloaded.pilotFitEvidence!.fitting.shipName, 'Rifter');
      expect(reloaded.pilotFitEvidence!.role, FitEvidenceRole.pilot);

      await harness.pumpScreen(tester, encounter: encounter);
      await harness.waitFor(
        tester,
        find.byKey(const Key('aar-evidence-row-pilotFit')),
      );
      expect(harness.codex.calls, 0);
      expect(harness.esiAdapter.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('U0 reopen over the same databases keeps the imported fit', (
    tester,
  ) async {
    final encounter = encounterWith(
      characterId: FitEvidenceHarness.characterAId,
    );
    await harness.enrichmentService.importPilotFit(
      encounter,
      '[Rifter, Test]\n',
    );
    await harness.pumpScreen(tester, encounter: encounter);
    await harness.reopen(tester, encounter: encounter);
    final reloaded = await harness.repository.loadEnrichment(encounter.id);
    expect(reloaded?.pilotFitEvidence?.fitting.shipTypeId, 587);
    expect(tester.takeException(), isNull);
  });

  test('U0 unexpected ESI HTTP is a harness failure', () async {
    await expectLater(
      () => harness.esiAdapter.fetch(
        RequestOptions(path: '/characters/42/ship/', method: 'GET'),
        null,
        null,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('unexpected ESI HTTP'),
        ),
      ),
    );
  });

  testWidgets('U0 teardown order leaves takeException clean', (tester) async {
    final encounter = encounterWith(
      characterId: FitEvidenceHarness.characterAId,
    );
    await harness.pumpScreen(tester, encounter: encounter);
    await harness.waitFor(tester, importFit);
    // Widgets, then ESI. Database close stays in group tearDown so
    // in-flight Drift work can finish; closing here deadlocks NativeDatabase.
    await harness.disposeWidgets(tester);
    await harness.disposeEsiWatch(tester);
    expect(tester.takeException(), isNull);
  });

  Future<void> openImportDialog(WidgetTester tester) async {
    await harness.waitFor(tester, importFit);
    await tester.ensureVisible(importFit);
    await tester.tap(importFit);
    await tester.pump();
    await harness.waitFor(tester, find.text('Import Pilot Fit'));
  }

  Future<void> submitImportDialog(WidgetTester tester, String rawFit) async {
    await tester.enterText(find.byType(TextField), rawFit);
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pump();
  }

  testWidgets(
    'T04 supported EFT does not succeed before commit and then persists',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      harness.repository.mutationEntered = Completer<void>();
      harness.repository.allowMutation = Completer<void>();
      await harness.pumpScreen(tester, encounter: encounter);
      await openImportDialog(tester);
      await submitImportDialog(tester, kAarSupportedEft);
      for (
        var i = 0;
        i < 40 && !harness.repository.mutationEntered!.isCompleted;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await harness.repository.mutationEntered!.future;
      expect(find.text(kAarImportSuccessMessage), findsNothing);
      expect(
        await CombatEnrichmentRepository(
          database: harness.appDb,
        ).loadEnrichment(encounter.id),
        isNull,
      );
      harness.repository.allowMutation!.complete();
      await harness.waitFor(tester, find.text(kAarImportSuccessMessage));
      expect(find.text(kAarImportSuccessMessage), findsOneWidget);
      final reloaded = await harness.repository.loadEnrichment(encounter.id);
      expect(
        reloaded!.pilotFitEvidence!.source,
        EvidenceSource.manualFitImport,
      );
      expect(reloaded.pilotFitEvidence!.fitting.lowSlots.single.typeId, 2048);
      expect(reloaded.pilotFitEvidence!.fitting.drones.single.quantity, 5);
      expect(harness.codex.calls, 0);
      expect(harness.discovery.fetches, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('T05 header-only import works without an encounter character', (
    tester,
  ) async {
    final encounter = encounterWith(characterId: null);
    await harness.pumpScreen(tester, encounter: encounter);
    await openImportDialog(tester);
    await submitImportDialog(tester, kAarHeaderOnlyEft);
    await harness.waitFor(tester, find.text(kAarImportSuccessMessage));
    final reloaded = await harness.repository.loadEnrichment(encounter.id);
    expect(reloaded!.pilotFitEvidence!.fitting.shipTypeId, 587);
    expect(reloaded.pilotFitEvidence!.fitting.allModules, isEmpty);
    expect(harness.esiAdapter.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T05 CRLF whitespace and placeholders persist the real module', (
    tester,
  ) async {
    final encounter = encounterWith(
      characterId: FitEvidenceHarness.characterAId,
    );
    await harness.pumpScreen(tester, encounter: encounter);
    await openImportDialog(tester);
    await submitImportDialog(tester, kAarWhitespaceCrlfEft);
    await harness.waitFor(tester, find.text(kAarImportSuccessMessage));
    var reloaded = await harness.repository.loadEnrichment(encounter.id);
    expect(reloaded!.pilotFitEvidence!.fitting.lowSlots.single.typeId, 2048);

    await openImportDialog(tester);
    await submitImportDialog(tester, kAarPlaceholderEft);
    await harness.waitFor(tester, find.text(kAarImportSuccessMessage));
    reloaded = await harness.repository.loadEnrichment(encounter.id);
    expect(reloaded!.pilotFitEvidence!.fitting.lowSlots.single.typeId, 2048);
    expect(reloaded.pilotFitEvidence!.fitting.medSlots, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T06 non-ship hull keeps the prior row and shows header copy', (
    tester,
  ) async {
    final encounter = encounterWith(
      characterId: FitEvidenceHarness.characterAId,
    );
    await harness.repository.saveEnrichment(
      CombatEnrichment(
        parsedEncounterId: encounter.id,
        status: CombatEnrichmentStatus.logOnly,
        source: CombatEnrichmentSource.none,
        matchReason: CombatEnrichment.uncachedMatchReason,
        pilotFitEvidence: FitEvidence(
          role: FitEvidenceRole.pilot,
          source: EvidenceSource.currentShipSnapshot,
          confidence: EvidenceConfidence.reference,
          fitting: const Fitting(
            id: 'prior-ref',
            name: 'Reference',
            shipTypeId: 587,
            shipName: 'Rifter',
          ),
        ),
      ),
    );
    await harness.pumpScreen(tester, encounter: encounter);
    await openImportDialog(tester);
    await submitImportDialog(tester, kAarNonShipHeaderEft);
    await harness.waitFor(tester, find.text(kAarMalformedUiMessage));
    expect(find.text(kAarMalformedUiMessage), findsOneWidget);
    expect(find.text('Import Pilot Fit'), findsNothing);
    expect(find.text(kAarImportSuccessMessage), findsNothing);
    final reloaded = await harness.repository.loadEnrichment(encounter.id);
    expect(reloaded!.pilotFitEvidence!.fitting.shipTypeId, 587);
    expect(reloaded.pilotFitEvidence!.fitting.shipName, 'Rifter');
    expect(tester.takeException(), isNull);
  });

  testWidgets('T07 colon EFT header saves through the dialog as EFT', (
    tester,
  ) async {
    final encounter = encounterWith(
      characterId: FitEvidenceHarness.characterAId,
    );
    await harness.pumpScreen(tester, encounter: encounter);
    await openImportDialog(tester);
    await submitImportDialog(tester, kAarColonHeaderEft);
    await harness.waitFor(tester, find.text(kAarImportSuccessMessage));
    expect(find.text(kAarImportSuccessMessage), findsOneWidget);
    final reloaded = await harness.repository.loadEnrichment(encounter.id);
    expect(reloaded, isNotNull);
    expect(reloaded!.pilotFitEvidence, isNotNull);
    expect(reloaded.pilotFitEvidence!.fitting.name, 'PvP: Armor');
    expect(reloaded.pilotFitEvidence!.fitting.lowSlots.single.typeId, 2048);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T08 mixed unknown entries never become confirmed evidence', (
    tester,
  ) async {
    final encounter = encounterWith(
      characterId: FitEvidenceHarness.characterAId,
    );
    await harness.pumpScreen(tester, encounter: encounter);
    await openImportDialog(tester);
    await submitImportDialog(tester, kAarMixedUnknownEft);
    await harness.waitFor(tester, find.text(kAarUnresolvedUiMessage));
    expect(find.text(kAarUnresolvedUiMessage), findsOneWidget);
    expect(find.text(kAarImportSuccessMessage), findsNothing);
    expect(await harness.repository.loadEnrichment(encounter.id), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T09 loaded ammunition is rejected with dedicated copy', (
    tester,
  ) async {
    final encounter = encounterWith(
      characterId: FitEvidenceHarness.characterAId,
    );
    await harness.pumpScreen(tester, encounter: encounter);
    await openImportDialog(tester);
    await submitImportDialog(tester, kAarAmmoSuffixEft);
    await harness.waitFor(tester, find.text(kAarAmmoUiMessage));
    expect(find.text(kAarAmmoUiMessage), findsOneWidget);
    expect(find.text(kAarImportSuccessMessage), findsNothing);
    expect(await harness.repository.loadEnrichment(encounter.id), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T10 exact hull beyond 20 partial matches imports', (
    tester,
  ) async {
    final encounter = encounterWith(
      characterId: FitEvidenceHarness.characterAId,
    );
    await harness.pumpScreen(tester, encounter: encounter);
    await openImportDialog(tester);
    await submitImportDialog(tester, kAarUniqueBeyond20Eft);
    await harness.waitFor(tester, find.text(kAarImportSuccessMessage));
    expect(find.text(kAarImportSuccessMessage), findsOneWidget);
    final reloaded = await harness.repository.loadEnrichment(encounter.id);
    expect(reloaded, isNotNull);
    expect(reloaded!.pilotFitEvidence, isNotNull);
    expect(reloaded.pilotFitEvidence!.fitting.shipTypeId, 9020);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'T12 failed dialog closes; retry replaces stale error and saves once',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.pumpScreen(tester, encounter: encounter);
      await openImportDialog(tester);
      await submitImportDialog(tester, kAarUnknownHullEft);
      await harness.waitFor(tester, find.text(kAarMalformedUiMessage));
      expect(find.text(kAarMalformedUiMessage), findsOneWidget);
      expect(find.text('Import Pilot Fit'), findsNothing);
      expect(harness.repository.saveCalls, 0);

      await openImportDialog(tester);
      await submitImportDialog(tester, kAarSupportedEft);
      await harness.waitFor(tester, find.text(kAarImportSuccessMessage));
      expect(find.text(kAarMalformedUiMessage), findsNothing);
      expect(harness.repository.saveCalls, 1);
      final reloaded = await harness.repository.loadEnrichment(encounter.id);
      expect(reloaded!.pilotFitEvidence!.fitting.shipTypeId, 587);
      expect(reloaded.pilotFitEvidence!.fitting.drones.single.quantity, 5);
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> tapUseCurrentFit(WidgetTester tester) async {
    await harness.waitFor(tester, useCurrentFit);
    await tester.ensureVisible(useCurrentFit);
    await tester.tap(useCurrentFit);
    await tester.pump();
  }

  Future<void> pumpCaptureScreen(
    WidgetTester tester,
    ParsedCombatEncounter encounter, {
    bool cached = false,
  }) async {
    if (cached) await harness.seedCachedReport(encounter);
    await harness.pumpScreen(tester, encounter: encounter);
  }

  testWidgets(
    'T13 confirmed capture from pre-analysis awaits save and exact success',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      final releaseShip = Completer<void>();
      harness.scriptFittedCapture(delayShip: releaseShip.future);
      await pumpCaptureScreen(tester, encounter);
      await tapUseCurrentFit(tester);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text(kAarCaptureSuccessMessage), findsNothing);
      expect(await harness.repository.loadEnrichment(encounter.id), isNull);
      releaseShip.complete();
      await harness.waitFor(tester, find.text(kAarCaptureSuccessMessage));
      expect(find.text(kAarCaptureSuccessMessage), findsOneWidget);
      final reloaded = await harness.repository.loadEnrichment(encounter.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.pilotFitEvidence, isNotNull);
      expect(
        reloaded.pilotFitEvidence!.source,
        EvidenceSource.currentShipSnapshot,
      );
      expect(
        reloaded.pilotFitEvidence!.confidence,
        EvidenceConfidence.confirmed,
      );
      expect(reloaded.pilotFitEvidence!.role, FitEvidenceRole.pilot);
      expect(reloaded.pilotFitEvidence!.fitting.shipTypeId, 587);
      expect(reloaded.pilotFitEvidence!.fitting.lowSlots.single.typeId, 2048);
      expect(reloaded.pilotFitEvidence!.fitting.highSlots, isEmpty);
      expect(
        reloaded.pilotFitEvidence!.fitting.lowSlots.single.chargeTypeId,
        185,
      );
      expect(reloaded.pilotFitEvidence!.fitting.drones.single.quantity, 5);
      expect(harness.repository.saveCalls, 1);
      expect(harness.codex.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T13 confirmed capture from a cached AAR uses the same success copy',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      harness.scriptFittedCapture();
      await pumpCaptureScreen(tester, encounter, cached: true);
      await tapUseCurrentFit(tester);
      await harness.waitFor(tester, find.text(kAarCaptureSuccessMessage));
      expect(find.text(kAarCaptureSuccessMessage), findsOneWidget);
      final reloaded = await harness.repository.loadEnrichment(encounter.id);
      expect(reloaded!.pilotFitEvidence!.fitting.shipTypeId, 587);
      expect(
        reloaded.pilotFitEvidence!.fitting.lowSlots.single.chargeTypeId,
        185,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T14 capture uses encounter A, both asset pages, and keeps the nested charge',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.activateCharacter(FitEvidenceHarness.characterBId);
      harness.scriptFittedCapture(twoPages: true, unrelated: true);
      await pumpCaptureScreen(tester, encounter);
      await tapUseCurrentFit(tester);
      await harness.waitFor(tester, find.text(kAarCaptureSuccessMessage));
      final paths = harness.esiAdapter.requests.map((r) => r.uri.path).toList();
      expect(
        paths.any(
          (p) =>
              p.contains('/characters/${FitEvidenceHarness.characterAId}/ship'),
        ),
        isTrue,
      );
      expect(
        paths.where(
          (p) => p.contains(
            '/characters/${FitEvidenceHarness.characterAId}/assets',
          ),
        ),
        hasLength(2),
      );
      expect(
        paths.any(
          (p) => p.contains('/characters/${FitEvidenceHarness.characterBId}/'),
        ),
        isFalse,
      );
      final pages = harness.esiAdapter.requests
          .where((r) => r.uri.path.contains('/assets'))
          .map((r) => r.queryParameters['page'])
          .toSet();
      expect(pages, containsAll([1, 2]));
      final reloaded = await harness.repository.loadEnrichment(encounter.id);
      expect(reloaded!.pilotFitEvidence!.fitting.lowSlots.single.typeId, 2048);
      expect(
        reloaded.pilotFitEvidence!.fitting.lowSlots.single.chargeTypeId,
        185,
      );
      expect(reloaded.pilotFitEvidence!.fitting.drones.single.typeId, 2456);
      expect(reloaded.pilotFitEvidence!.fitting.medSlots, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('T15 later asset page failure does not save a partial fit', (
    tester,
  ) async {
    final encounter = encounterWith(
      characterId: FitEvidenceHarness.characterAId,
    );
    await harness.repository.saveEnrichment(
      CombatEnrichment(
        parsedEncounterId: encounter.id,
        status: CombatEnrichmentStatus.logOnly,
        source: CombatEnrichmentSource.none,
        matchReason: CombatEnrichment.uncachedMatchReason,
        pilotFitEvidence: FitEvidence(
          role: FitEvidenceRole.pilot,
          source: EvidenceSource.manualFitImport,
          confidence: EvidenceConfidence.reference,
          fitting: const Fitting(
            id: 'prior',
            name: 'Prior',
            shipTypeId: 587,
            shipName: 'Rifter',
          ),
        ),
      ),
    );
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
      body: {'error': 'service unavailable'},
      totalPages: 2,
      statusCode: 500,
    );
    await pumpCaptureScreen(tester, encounter);
    await tapUseCurrentFit(tester);
    await harness.waitFor(tester, find.text(kAarCaptureAssetsUi));
    expect(find.text(kAarCaptureAssetsUi), findsOneWidget);
    expect(find.text(kAarCaptureSuccessMessage), findsNothing);
    expect(find.textContaining('DioException'), findsNothing);
    final reloaded = await harness.repository.loadEnrichment(encounter.id);
    expect(reloaded!.pilotFitEvidence!.source, EvidenceSource.manualFitImport);
    expect(reloaded.pilotFitEvidence!.fitting.name, 'Prior');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'T16 null encounter character never calls ESI and still allows import',
    (tester) async {
      final encounter = encounterWith(characterId: null);
      await harness.activateCharacter(FitEvidenceHarness.characterBId);
      harness.scriptFittedCapture(characterId: FitEvidenceHarness.characterBId);
      await pumpCaptureScreen(tester, encounter);
      await tapUseCurrentFit(tester);
      await harness.waitFor(tester, find.text(kAarCaptureNoCharacterUi));
      expect(find.text(kAarCaptureNoCharacterUi), findsOneWidget);
      expect(harness.esiAdapter.requests, isEmpty);
      expect(find.text(kAarCaptureSuccessMessage), findsNothing);

      await openImportDialog(tester);
      await submitImportDialog(tester, kAarHeaderOnlyEft);
      await harness.waitFor(tester, find.text(kAarImportSuccessMessage));
      final reloaded = await harness.repository.loadEnrichment(encounter.id);
      expect(
        reloaded!.pilotFitEvidence!.source,
        EvidenceSource.manualFitImport,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('T17 collapsed ship transport uses the no-ship copy', (
    tester,
  ) async {
    final encounter = encounterWith(
      characterId: FitEvidenceHarness.characterAId,
    );
    await harness.repository.saveEnrichment(
      CombatEnrichment(
        parsedEncounterId: encounter.id,
        status: CombatEnrichmentStatus.logOnly,
        source: CombatEnrichmentSource.none,
        matchReason: CombatEnrichment.uncachedMatchReason,
        pilotFitEvidence: FitEvidence(
          role: FitEvidenceRole.pilot,
          source: EvidenceSource.manualFitImport,
          confidence: EvidenceConfidence.reference,
          fitting: const Fitting(
            id: 'prior',
            name: 'Prior',
            shipTypeId: 587,
            shipName: 'Rifter',
          ),
        ),
      ),
    );
    harness.scriptCharacterShip(statusCode: 404);
    await pumpCaptureScreen(tester, encounter);
    await tapUseCurrentFit(tester);
    await harness.waitFor(tester, find.text(kAarCaptureNoShipUi));
    expect(find.text(kAarCaptureNoShipUi), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('FormatException'), findsNothing);
    expect(
      harness.esiAdapter.requests.where((r) => r.uri.path.contains('/assets')),
      isEmpty,
    );
    final reloaded = await harness.repository.loadEnrichment(encounter.id);
    expect(reloaded!.pilotFitEvidence!.fitting.name, 'Prior');
    expect(tester.takeException(), isNull);
  });

  testWidgets('T17 missing token uses the reauthorize copy', (tester) async {
    final encounter = encounterWith(
      characterId: FitEvidenceHarness.characterAId,
    );
    await harness.tokenManager.deleteTokens(FitEvidenceHarness.characterAId);
    await pumpCaptureScreen(tester, encounter);
    await tapUseCurrentFit(tester);
    await harness.waitFor(tester, find.text(kAarCaptureAuthUi));
    expect(find.text(kAarCaptureAuthUi), findsOneWidget);
    expect(find.textContaining('EsiException'), findsNothing);
    expect(find.textContaining('access-a'), findsNothing);
    expect(harness.esiAdapter.requests, isEmpty);
    expect(find.text(kAarCaptureSuccessMessage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'T18 empty inventory is a hull-only snapshot with qualified success',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      harness.scriptFittedCapture(emptyInventory: true);
      await pumpCaptureScreen(tester, encounter);
      await tapUseCurrentFit(tester);
      await harness.waitFor(tester, find.text(kAarCaptureEmptySuccessMessage));
      expect(find.text(kAarCaptureEmptySuccessMessage), findsOneWidget);
      expect(find.text(kAarCaptureSuccessMessage), findsNothing);
      final reloaded = await harness.repository.loadEnrichment(encounter.id);
      expect(
        reloaded!.pilotFitEvidence!.confidence,
        EvidenceConfidence.confirmed,
      );
      expect(reloaded.pilotFitEvidence!.fitting.shipTypeId, 587);
      expect(reloaded.pilotFitEvidence!.fitting.allModules, isEmpty);
      expect(reloaded.pilotFitEvidence!.fitting.drones, isEmpty);
      expect(
        reloaded.pilotFitEvidence!.limitations,
        contains(kAarEmptyModulesLimitation),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('T19 reference capture reloads as Inferred with both live CTAs', (
    tester,
  ) async {
    final encounter = encounterWith(
      characterId: FitEvidenceHarness.characterAId,
    );
    harness.scriptFittedCapture();
    await tester.runAsync(() {
      return harness.enrichmentService.captureCurrentPilotFit(
        encounter,
        confirmed: false,
      );
    });
    await pumpCaptureScreen(tester, encounter);
    await harness.waitFor(tester, importFit);
    expect(importFit, findsOneWidget);
    expect(useCurrentFit, findsOneWidget);
    expect(find.text('Snapshot Current Fit'), findsNothing);
    expect(find.text('Use Current Fit For This Fight'), findsNothing);
    final reloaded = await harness.repository.loadEnrichment(encounter.id);
    expect(
      reloaded!.pilotFitEvidence!.confidence,
      EvidenceConfidence.reference,
    );
    expect(
      reloaded.pilotFitEvidence!.source,
      EvidenceSource.currentShipSnapshot,
    );
    expect(find.textContaining('Inferred'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'T20 Use Current Fit fetches ship B instead of relabeling reference A',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      harness.scriptFittedCapture();
      final reference = await tester.runAsync(() {
        return harness.enrichmentService.captureCurrentPilotFit(
          encounter,
          confirmed: false,
        );
      });
      expect(reference, isNotNull);
      expect(
        reference!.pilotFitEvidence!.fitting.id,
        contains('$kAarShipItemId'),
      );
      harness.esiAdapter.requests.clear();
      harness.esiAdapter.clearScripts();
      harness.scriptFittedCapture(
        shipTypeId: kAarShipBTypeId,
        shipItemId: kAarShipBItemId,
        shipName: 'UniqueShip',
        shipTypeName: 'UniqueShip',
      );
      await pumpCaptureScreen(tester, encounter);
      await tapUseCurrentFit(tester);
      await harness.waitFor(tester, find.text(kAarCaptureSuccessMessage));
      final reloaded = await harness.repository.loadEnrichment(encounter.id);
      expect(
        reloaded!.pilotFitEvidence!.confidence,
        EvidenceConfidence.confirmed,
      );
      expect(reloaded.pilotFitEvidence!.fitting.shipTypeId, kAarShipBTypeId);
      expect(reloaded.pilotFitEvidence!.fitting.shipName, 'UniqueShip');
      expect(
        reloaded.pilotFitEvidence!.fitting.id,
        contains('$kAarShipBItemId'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('T34 capture errors are categorized and never dump transport', (
    tester,
  ) async {
    final encounter = encounterWith(
      characterId: FitEvidenceHarness.characterAId,
    );
    harness.scriptFittedCapture();
    harness.repository.failWith = StateError('sqlite boom token=access-a');
    await pumpCaptureScreen(tester, encounter);
    await tapUseCurrentFit(tester);
    await harness.waitFor(tester, find.text(kAarCaptureSaveUi));
    expect(find.text(kAarCaptureSaveUi), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
    expect(find.textContaining('access-a'), findsNothing);
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.text(kAarCaptureSuccessMessage), findsNothing);
    expect(await harness.repository.loadEnrichment(encounter.id), isNull);
    expect(tester.takeException(), isNull);
  });

  Future<void> tapReanalyze(WidgetTester tester) async {
    final provenance = find.byKey(const Key('aar-provenance-reanalyze'));
    final strip = find.widgetWithText(OutlinedButton, 'Re-analyze');
    final target = provenance.evaluate().isNotEmpty ? provenance : strip;
    await harness.waitFor(tester, target);
    await tester.ensureVisible(target.first);
    await tester.tap(target.first);
    await tester.pump();
  }

  Future<void> waitForCodexCall(
    WidgetTester tester, {
    int pumps = 80,
    int calls = 1,
  }) async {
    for (var i = 0; i < pumps && harness.codex.calls < calls; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'T11 valid import with repository save failure keeps prior evidence',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.repository.saveEnrichment(
        CombatEnrichment(
          parsedEncounterId: encounter.id,
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
          pilotFitEvidence: const FitEvidence(
            role: FitEvidenceRole.pilot,
            source: EvidenceSource.currentShipSnapshot,
            confidence: EvidenceConfidence.reference,
            fitting: Fitting(
              id: 'prior-ref',
              name: 'Reference',
              shipTypeId: 587,
              shipName: 'Rifter',
            ),
          ),
        ),
      );
      harness.repository.failWith = StateError('boom');
      await harness.pumpScreen(tester, encounter: encounter);
      await openImportDialog(tester);
      await submitImportDialog(tester, kAarSupportedEft);
      await harness.waitFor(tester, find.text(kAarImportSaveUi));
      expect(find.text(kAarImportSaveUi), findsOneWidget);
      expect(find.text(kAarImportSuccessMessage), findsNothing);
      expect(find.textContaining('boom'), findsNothing);
      final reloaded = await CombatEnrichmentRepository(
        database: harness.appDb,
      ).loadEnrichment(encounter.id);
      expect(reloaded, isNotNull);
      expect(
        reloaded!.pilotFitEvidence!.confidence,
        EvidenceConfidence.reference,
      );
      expect(reloaded.pilotFitEvidence!.fitting.id, 'prior-ref');
      expect(
        reloaded.pilotFitEvidence!.source,
        EvidenceSource.currentShipSnapshot,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T21 imported fit survives provider dispose/reopen and leaves encounter B unchanged',
    (tester) async {
      final encounterA = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      final encounterB = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
        incomingEvents: 3,
        outgoingEvents: 3,
      );
      expect(encounterA.id, isNot(encounterB.id));
      await harness.repository.saveEnrichment(
        CombatEnrichment(
          parsedEncounterId: encounterB.id,
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
          matchReason: 'encounter-b-seed',
        ),
      );
      await harness.pumpScreen(tester, encounter: encounterA);
      await openImportDialog(tester);
      await submitImportDialog(tester, kAarSupportedEft);
      await harness.waitFor(tester, find.text(kAarImportSuccessMessage));
      final aiBefore = harness.codex.calls;
      final discoveryBefore = harness.discovery.fetches.length;
      await harness.reopen(tester, encounter: encounterA);
      final reloadedA = await CombatEnrichmentRepository(
        database: harness.appDb,
      ).loadEnrichment(encounterA.id);
      expect(reloadedA, isNotNull);
      expect(
        reloadedA!.pilotFitEvidence!.source,
        EvidenceSource.manualFitImport,
      );
      expect(
        reloadedA.pilotFitEvidence!.confidence,
        EvidenceConfidence.confirmed,
      );
      expect(reloadedA.pilotFitEvidence!.fitting.shipTypeId, 587);
      expect(reloadedA.pilotFitEvidence!.fitting.lowSlots.single.typeId, 2048);
      final reloadedB = await CombatEnrichmentRepository(
        database: harness.appDb,
      ).loadEnrichment(encounterB.id);
      expect(reloadedB, isNotNull);
      expect(reloadedB!.matchReason, 'encounter-b-seed');
      expect(reloadedB.pilotFitEvidence, isNull);
      expect(harness.codex.calls, aiBefore);
      expect(harness.discovery.fetches.length, discoveryBefore);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T21 captured fit survives provider dispose/reopen and leaves encounter B unchanged',
    (tester) async {
      final encounterA = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      final encounterB = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
        incomingEvents: 3,
        outgoingEvents: 3,
      );
      await harness.repository.saveEnrichment(
        CombatEnrichment(
          parsedEncounterId: encounterB.id,
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
          matchReason: 'encounter-b-seed',
        ),
      );
      harness.scriptFittedCapture();
      await pumpCaptureScreen(tester, encounterA);
      await tapUseCurrentFit(tester);
      await harness.waitFor(tester, find.text(kAarCaptureSuccessMessage));
      final aiBefore = harness.codex.calls;
      final discoveryBefore = harness.discovery.fetches.length;
      await harness.reopen(tester, encounter: encounterA);
      final reloadedA = await CombatEnrichmentRepository(
        database: harness.appDb,
      ).loadEnrichment(encounterA.id);
      expect(
        reloadedA!.pilotFitEvidence!.source,
        EvidenceSource.currentShipSnapshot,
      );
      expect(
        reloadedA.pilotFitEvidence!.confidence,
        EvidenceConfidence.confirmed,
      );
      expect(reloadedA.pilotFitEvidence!.fitting.shipTypeId, 587);
      final reloadedB = await CombatEnrichmentRepository(
        database: harness.appDb,
      ).loadEnrichment(encounterB.id);
      expect(reloadedB!.matchReason, 'encounter-b-seed');
      expect(reloadedB.pilotFitEvidence, isNull);
      expect(harness.codex.calls, aiBefore);
      expect(harness.discovery.fetches.length, discoveryBefore);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T22 import replacement keeps unrelated enrichment and a single pilot fact',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.seedUnrelatedEnrichment(encounter);
      await harness.pumpScreen(tester, encounter: encounter);
      await openImportDialog(tester);
      await submitImportDialog(tester, kAarSupportedEft);
      await harness.waitFor(tester, find.text(kAarImportSuccessMessage));
      final reloaded = await harness.repository.loadEnrichment(encounter.id);
      expect(reloaded, isNotNull);
      _assertUnrelatedEnrichmentPreserved(reloaded!, encounter.id);
      expect(reloaded.pilotFitEvidence!.source, EvidenceSource.manualFitImport);
      expect(
        reloaded.pilotFitEvidence!.confidence,
        EvidenceConfidence.confirmed,
      );
      expect(reloaded.pilotFitEvidence!.fitting.lowSlots.single.typeId, 2048);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T22 capture replacement keeps unrelated enrichment and a single pilot fact',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.seedUnrelatedEnrichment(encounter);
      harness.scriptFittedCapture();
      await pumpCaptureScreen(tester, encounter);
      await tapUseCurrentFit(tester);
      await harness.waitFor(tester, find.text(kAarCaptureSuccessMessage));
      final reloaded = await harness.repository.loadEnrichment(encounter.id);
      expect(reloaded, isNotNull);
      _assertUnrelatedEnrichmentPreserved(reloaded!, encounter.id);
      expect(
        reloaded.pilotFitEvidence!.source,
        EvidenceSource.currentShipSnapshot,
      );
      expect(
        reloaded.pilotFitEvidence!.confidence,
        EvidenceConfidence.confirmed,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T26 Re-analyze after manual import retains the attached fit into AI',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.seedCachedReport(encounter);
      await harness.grantKillmailScope();
      harness.scriptNoMatchKillmails();
      await harness.pumpScreen(tester, encounter: encounter);
      await openImportDialog(tester);
      await submitImportDialog(tester, kAarSupportedEft);
      await harness.waitFor(tester, find.text(kAarImportSuccessMessage));
      await tapReanalyze(tester);
      await waitForCodexCall(tester);
      expect(harness.codex.calls, 1);
      _assertRetainedPilotFit(
        stored: await harness.repository.loadEnrichment(encounter.id),
        received: harness.codex.lastEnrichment,
        derivation: harness.codex.lastDerivation,
        source: EvidenceSource.manualFitImport,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T27 AI failure keeps the new fit and cached report; retry uses the fit',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.seedCachedReport(encounter);
      await harness.grantKillmailScope();
      harness.scriptNoMatchKillmails();
      await harness.pumpScreen(tester, encounter: encounter);
      await openImportDialog(tester);
      await submitImportDialog(tester, kAarSupportedEft);
      await harness.waitFor(tester, find.text(kAarImportSuccessMessage));
      harness.codex.error = StateError('ai down');
      await tapReanalyze(tester);
      await harness.waitFor(tester, find.text('Analysis Failed'));
      expect(find.text('Analysis Failed'), findsOneWidget);
      expect(
        (await harness.repository.loadEnrichment(
          encounter.id,
        ))!.pilotFitEvidence,
        isNotNull,
        reason: 'AI failure must not drop the newly attached pilot fit',
      );
      final cached = await harness.analysisService.getCachedAnalysis(encounter);
      expect(cached, isNotNull);
      expect(cached!.llmSummary, 'Cached summary');
      harness.codex.error = null;
      harness.codex.result = CodexAnalysisResult(
        report: CombatAarReport.fromLegacy(
          summary: 'Retry summary',
          mistakes: '',
          improvements: '',
          fits: '',
        ),
      );
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Back To Encounter'),
      );
      await tester.pump();
      await tapReanalyze(tester);
      await waitForCodexCall(tester, calls: 2);
      _assertRetainedPilotFit(
        stored: await harness.repository.loadEnrichment(encounter.id),
        received: harness.codex.lastEnrichment,
        derivation: harness.codex.lastDerivation,
        source: EvidenceSource.manualFitImport,
      );
      final retried = await harness.analysisService.getCachedAnalysis(
        encounter,
      );
      expect(retried!.llmSummary, 'Retry summary');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'T30 pending import rejects competing capture and queues explicit analysis',
    (tester) async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      harness.scriptFittedCapture();
      harness.repository.mutationEntered = Completer<void>();
      harness.repository.allowMutation = Completer<void>();
      await harness.pumpScreen(tester, encounter: encounter);
      await openImportDialog(tester);
      await submitImportDialog(tester, kAarSupportedEft);
      for (
        var i = 0;
        i < 40 && !harness.repository.mutationEntered!.isCompleted;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await harness.repository.mutationEntered!.future;
      expect(harness.repository.saveCalls, 1);
      expect(find.text(kAarImportSuccessMessage), findsNothing);
      await tapUseCurrentFit(tester);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        harness.repository.saveCalls,
        1,
        reason: 'competing capture must be rejected while attachment is busy',
      );
      await tester.tap(find.byKey(const Key('aar-analyze-button')));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(harness.codex.calls, 0);
      harness.repository.allowMutation!.complete();
      await harness.waitFor(tester, find.text(kAarImportSuccessMessage));
      await waitForCodexCall(tester);
      expect(harness.codex.calls, 1);
      _assertRetainedPilotFit(
        stored: await harness.repository.loadEnrichment(encounter.id),
        received: harness.codex.lastEnrichment,
        derivation: harness.codex.lastDerivation,
        source: EvidenceSource.manualFitImport,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

void _assertUnrelatedEnrichmentPreserved(
  CombatEnrichment enrichment,
  String encounterId,
) {
  expect(enrichment.killmailId, kAarKillmailId);
  expect(enrichment.killmailHash, kAarKillmailHash);
  expect(enrichment.killmailSearchCompleted, isTrue);
  expect(enrichment.victimFitEvidence, isNotNull);
  expect(enrichment.victimFitEvidence!.role, FitEvidenceRole.victim);
  expect(enrichment.victimFitEvidence!.fitting.shipTypeId, 587);
  expect(enrichment.attackerCorrelation, isNotNull);
  expect(enrichment.attackerCorrelation!.killmailId, kAarKillmailId);
  final factIds = enrichment.evidenceLedger.facts
      .map((fact) => fact.id)
      .toList();
  expect(factIds.where((id) => id == 'ev-pilot-fit-$encounterId'), [
    'ev-pilot-fit-$encounterId',
  ]);
  expect(factIds, contains('ev-killmail-$kAarKillmailId'));
  expect(factIds, contains('ev-victim-ship-$kAarKillmailId'));
  expect(
    factIds,
    contains('ev-correlated-attacker-$kAarKillmailId-$kAarVictimCharacterId'),
  );
  expect(factIds, contains('ev-custom-note-$encounterId'));
  expect(
    enrichment.evidenceLedger.unknowns.map((unknown) => unknown.label),
    containsAll(['Attacker fits', 'Range and transversal']),
  );
}

void _assertRetainedPilotFit({
  required CombatEnrichment? stored,
  required CombatEnrichment? received,
  required AarDerivationBundle? derivation,
  required EvidenceSource source,
}) {
  expect(stored, isNotNull, reason: 'stored enrichment missing after refresh');
  expect(
    stored!.pilotFitEvidence,
    isNotNull,
    reason: 'stored pilotFitEvidence was dropped',
  );
  expect(stored.pilotFitEvidence!.source, source);
  expect(stored.pilotFitEvidence!.confidence, EvidenceConfidence.confirmed);
  expect(stored.pilotFitEvidence!.fitting.shipTypeId, 587);
  expect(
    received?.pilotFitEvidence,
    isNotNull,
    reason: 'codex.lastEnrichment.pilotFitEvidence was dropped',
  );
  expect(received!.pilotFitEvidence!.source, source);
  expect(received.pilotFitEvidence!.fitting.shipTypeId, 587);
  expect(
    derivation?.self,
    isNotNull,
    reason: 'codex.lastDerivation.self was not built from the attached fit',
  );
  expect(derivation!.self!.shipTypeId, 587);
  expect(derivation.self!.fitSource, source);
}
