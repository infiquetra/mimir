import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/presentation/analysis_multipane_screen.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_evidence_checklist_card.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_pre_analysis_gate.dart';

import '../fixtures/aar_evidence_fixtures.dart';
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
}
