import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
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
}
