// W6 RED contracts for the read-only comparison workspace and dialogs.
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §8.1–§8.4 / product U01–U16:
// - U01: Compare fits is missing from pre-analysis and the Fits tab.
// - U02: layout uses window width and always four columns.
// - U03: 320px / 200% text overflows horizontally.
// - U04: headers emit Type # / character ids; own-loss chip absent.
// - U05: only high slots; unresolved rows show Type #.
// - U06: color-only dots; no Show all / Changes only / empty copy.
// - U07: winner claim; omni EHP; missing F3/F4 formatted rows.
// - U08: no BOM mode toggle / target-baseline header / removals.
// - U09: "Total cost" instead of priced subtotal + freshness.
// - U10: profile defaults to EM and watches correlation on view.
// - U11/U14: evidence-path / placeholder snackbars, not §8.4 copy.
// - U12: dialog pops on error; submit has no isSubmitting CAS.
// - U13: origin / unstructured disclosures omitted.
// - U15: opening the workspace watches correlation.
// - U16: capture timer is not cancelled on dispose.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';
import 'package:mimir/features/combat_analyzer/data/aar_fit_comparison_service.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_bom.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_calculation.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_comparison.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart'
    hide AarFitSubject;
import 'package:mimir/features/combat_analyzer/domain/aar_fit_inventory_diff.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_pricing.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_proposal.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_snapshot.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_spares.dart';
import 'package:mimir/features/combat_analyzer/domain/tank_classifier.dart';
import 'package:mimir/features/combat_analyzer/presentation/analysis_multipane_screen.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_fit_bom_view.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_fit_comparison_card.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_fit_comparison_workspace.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_pre_analysis_gate.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_proposal_dialog.dart';
import 'package:mimir/features/fitting/domain/models.dart';

import '../fixtures/aar_comparison_fixtures.dart';
import '../fixtures/aar_evidence_fixtures.dart';
import '../fixtures/fit_evidence_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final recordedAt = DateTime.utc(2026, 9, 15, 12);

  AarComparisonSources fourRoleSources() {
    final fight = AarComparisonFixtures.snapshotOf(
      AarComparisonFixtures.f1Baseline(),
      snapshotId: 'fight',
      source: AarFitSource.evidenceAttachment,
      recordedAt: recordedAt,
      subject: const AarFitSubject(
        characterId: 42,
        relation: AarFitSubjectRelation.pilot,
      ),
    );
    final current = AarComparisonFixtures.snapshotOf(
      AarComparisonFixtures.f1Target(),
      snapshotId: 'current',
      source: AarFitSource.comparisonCapture,
      recordedAt: recordedAt.add(const Duration(hours: 1)),
    );
    final victim = AarComparisonFixtures.f5VictimQ();
    final proposal = AarComparisonFixtures.snapshotOf(
      AarComparisonFixtures.f1Target(),
      snapshotId: 'proposal',
      source: AarFitSource.aiProposal,
    );
    return AarComparisonSources(
      entries: [
        AarComparisonSourceEntry(
          id: fight.snapshotId,
          role: AarComparisonRole.fightFit,
          snapshot: fight,
          label: 'Fight fit',
        ),
        AarComparisonSourceEntry(
          id: current.snapshotId,
          role: AarComparisonRole.currentSnapshot,
          snapshot: current,
          label: 'Current snapshot',
        ),
        AarComparisonSourceEntry(
          id: victim.snapshotId,
          role: AarComparisonRole.victim,
          snapshot: victim,
          label: 'Victim fit',
        ),
        AarComparisonSourceEntry(
          id: proposal.snapshotId,
          role: AarComparisonRole.proposal,
          snapshot: proposal,
          label: 'AI proposal',
        ),
      ],
    );
  }

  AarFitComparisonWorkspace workspace({
    AarComparisonSources? sources,
    FitInventoryDiff? diff,
    CombatFitComputation? baseline,
    CombatFitComputation? candidate,
    FitBillOfMaterials? bom,
    AarPricedSubtotal? priced,
    List<AarCachedAssetMatch> matches = const [],
    AarFitProposal? proposal,
    String? currentBaselineSnapshotId,
    String selectedProfileId = 'em',
    ValueChanged<String>? onProfileChanged,
    Future<AarComparisonSaveResult> Function()? onCaptureCurrent,
    Future<AarComparisonSaveResult> Function()? onRefreshPrices,
    VoidCallback? onWatchCorrelation,
    List<SavedFittingReference> savedReferences = const [],
    bool priceRefreshHasCache = true,
  }) {
    return AarFitComparisonWorkspace(
      encounterId: 'enc-w6',
      sources: sources ?? fourRoleSources(),
      diff: diff,
      baseline: baseline,
      candidate: candidate,
      bom: bom,
      priced: priced,
      matches: matches,
      proposal: proposal,
      currentBaselineSnapshotId: currentBaselineSnapshotId,
      selectedProfileId: selectedProfileId,
      onProfileChanged: onProfileChanged,
      onCaptureCurrent: onCaptureCurrent,
      onRefreshPrices: onRefreshPrices,
      onWatchCorrelation: onWatchCorrelation,
      savedReferences: savedReferences,
      priceRefreshHasCache: priceRefreshHasCache,
    );
  }

  Future<void> pumpWorkspace(
    WidgetTester tester, {
    required Widget child,
    Size window = const Size(1600, 1200),
    double usableWidth = 1440,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: window,
            devicePixelRatio: 1,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: usableWidth,
                height: window.height,
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  const coverage = AarFitCoverage(
    highFitted: 1,
    highSlots: 1,
    medFitted: 0,
    medSlots: 0,
    lowFitted: 0,
    lowSlots: 0,
    rigFitted: 0,
    rigSlots: 0,
    subsystemFitted: 0,
    subsystemSlots: 0,
    unresolvedTypeIds: [],
    unresolvedNames: [],
  );

  const tank = TankAssessment(
    layer: TankLayer.armor,
    mode: TankMode.active,
    shieldBoostHps: 0,
    armorRepairHps: 100,
    hullRepairHps: 0,
    shieldGainEhp: 0,
    armorGainEhp: 0,
    hullGainEhp: 0,
    reasoning: 'fixture',
  );

  CombatFitComputation computation({
    required double totalEhp,
    required double capacitorStable,
    required bool isCapStable,
    double dpsTotal = 400,
    double volley = 890,
  }) {
    return CombatFitComputation(
      stats: FittingStats(
        capacitorStable: capacitorStable,
        isCapStable: isCapStable,
        dpsTotal: dpsTotal,
        volley: volley,
        defenses: DefenseProfile(
          shieldHp: F3Oracle.layerHp,
          armorHp: F3Oracle.layerHp,
          hullHp: F3Oracle.layerHp,
          totalEhp: totalEhp,
          effectiveArmorRepair: F4Oracle.burstRepairHps,
          peakShieldRecharge: F4Oracle.peakPassiveHps,
          shieldResists: const ResistProfile(
            em: 50,
            thermal: 20,
            kinetic: 40,
            explosive: 10,
          ),
        ),
      ),
      bareHullStats: const FittingStats(),
      tank: tank,
      coverage: coverage,
    );
  }

  Fitting eightGroupFit() {
    FittedModule slot(SlotType type, int typeId) {
      return FittedModule(
        typeId: typeId,
        typeName: 'Cmp $typeId',
        slotType: type,
        slotIndex: 0,
      );
    }

    return Fitting(
      id: 'eight',
      name: 'Eight groups',
      shipTypeId: kCmpHullH,
      shipName: 'Cmp H',
      highSlots: [
        AarComparisonFixtures.moduleA(
          state: ModuleState.offline,
          chargeTypeId: kCmpChargeY,
          chargeName: 'Cmp Y',
        ),
      ],
      medSlots: [AarComparisonFixtures.moduleB()],
      lowSlots: [slot(SlotType.low, 91601)],
      rigSlots: [slot(SlotType.rig, 91701)],
      subsystems: [slot(SlotType.subsystem, 91801)],
      drones: [AarComparisonFixtures.dronesD()],
      fighters: const [
        FighterGroup(typeId: 91901, typeName: 'Cmp Fighter', quantity: 1),
      ],
      cargo: [AarComparisonFixtures.ammo()],
    );
  }

  group('U01 reachability', () {
    late FitEvidenceHarness harness;

    setUp(() async {
      harness = FitEvidenceHarness();
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    testWidgets(
      'U01 pre-analysis Compare fits is reachable and does not call AI',
      (tester) async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        await harness.pumpScreen(tester, encounter: encounter);
        await harness.waitFor(
          tester,
          find.byKey(const Key('aar-analyze-button')),
        );
        expect(find.byType(AnalysisMultiPaneScreen), findsOneWidget);
        expect(find.byType(AarPreAnalysisGate), findsOneWidget);
        expect(find.text('Compare fits'), findsOneWidget);
        expect(find.byKey(const Key('aar-compare-fits-entry')), findsOneWidget);
        expect(harness.codex.calls, 0);
        expect(harness.discovery.fetches, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'U01 post-analysis Fits tab hosts the workspace without generating',
      (tester) async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        await harness.seedCachedReport(encounter);
        await harness.pumpScreen(tester, encounter: encounter);
        final fitsTab = find.text('Fits');
        await harness.waitFor(tester, fitsTab);
        await tester.ensureVisible(fitsTab);
        await tester.tap(fitsTab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(AarFitComparisonWorkspace), findsOneWidget);
        expect(find.text('Compare fits'), findsNothing);
        expect(harness.codex.calls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('U02 responsive breakpoints', () {
    test('U02 usable-width thresholds map to stacked / +1 / +2 / four', () {
      expect(
        aarComparisonLayoutModeForWidth(719),
        AarComparisonLayoutMode.stacked,
      );
      expect(
        aarComparisonLayoutModeForWidth(720),
        AarComparisonLayoutMode.baselinePlusOne,
      );
      expect(
        aarComparisonLayoutModeForWidth(999),
        AarComparisonLayoutMode.baselinePlusOne,
      );
      expect(
        aarComparisonLayoutModeForWidth(1000),
        AarComparisonLayoutMode.baselinePlusTwo,
      );
      expect(
        aarComparisonLayoutModeForWidth(1439),
        AarComparisonLayoutMode.baselinePlusTwo,
      );
      expect(
        aarComparisonLayoutModeForWidth(1440),
        AarComparisonLayoutMode.fourColumn,
      );
    });

    testWidgets('U02 LayoutBuilder uses usable width, not window width', (
      tester,
    ) async {
      Future<void> pumpAt(double usable, String layoutName) async {
        await pumpWorkspace(
          tester,
          child: workspace(),
          window: const Size(1600, 1200),
          usableWidth: usable,
        );
        expect(
          find.byKey(Key('aar-comparison-layout-$layoutName')),
          findsOneWidget,
        );
      }

      await pumpAt(719, 'stacked');
      expect(
        find.byKey(const Key('aar-comparison-source-tab-current')),
        findsOneWidget,
      );
      await pumpAt(720, 'baselinePlusOne');
      await pumpAt(999, 'baselinePlusOne');
      await pumpAt(1000, 'baselinePlusTwo');
      await pumpAt(1439, 'baselinePlusTwo');
      await pumpAt(1440, 'fourColumn');
    });

    testWidgets('U02 selected candidate is retained across resize', (
      tester,
    ) async {
      await pumpWorkspace(tester, child: workspace(), usableWidth: 1440);
      await tester.tap(find.byKey(const Key('aar-comparison-select-proposal')));
      await tester.pump();
      await pumpWorkspace(tester, child: workspace(), usableWidth: 720);
      expect(
        find.byKey(const Key('aar-comparison-layout-baselinePlusOne')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('aar-comparison-column-proposal')),
        findsOneWidget,
      );
    });
  });

  group('U03 accessibility overflow', () {
    testWidgets('U03 320px at 200% text does not overflow the page', (
      tester,
    ) async {
      FlutterErrorDetails? overflow;
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          overflow = details;
        }
        previous?.call(details);
      };
      addTearDown(() => FlutterError.onError = previous);

      await pumpWorkspace(
        tester,
        child: workspace(),
        window: const Size(320, 800),
        usableWidth: 320,
        textScale: 2,
      );
      expect(overflow, isNull);
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
        findsNothing,
      );
      expect(find.byType(AarFitComparisonWorkspace), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        find.byKey(const Key('aar-comparison-source-selector')),
        findsOneWidget,
      );
    });
  });

  group('U04 source headers', () {
    testWidgets(
      'U04 headers show role, subject, hull, provenance, time, F5 confidence',
      (tester) async {
        final sources = fourRoleSources();
        await pumpWorkspace(tester, child: workspace(sources: sources));
        expect(find.text('Fight fit'), findsWidgets);
        expect(find.text('Current snapshot'), findsWidgets);
        expect(find.text('Victim fit'), findsWidgets);
        expect(find.text('Cmp H'), findsWidgets);
        expect(find.textContaining('Type #'), findsNothing);
        expect(find.textContaining('Ship #'), findsNothing);
        expect(find.textContaining('character 42'), findsNothing);
        expect(find.textContaining('character 99'), findsNothing);
        expect(find.textContaining('2026'), findsWidgets);
        expect(find.textContaining('confirmed'), findsWidgets);
      },
    );

    testWidgets('U04 own-loss source is deduplicated with a disclosure chip', (
      tester,
    ) async {
      final victim = AarComparisonFixtures.f5VictimP();
      final sources = AarComparisonSources.resolve(
        encounterPilotId: 42,
        identityKnown: true,
        isVictory: false,
        victim: victim,
        generationBaseline: victim,
      );
      expect(sources.ownLossDeduplicated, isTrue);
      await pumpWorkspace(tester, child: workspace(sources: sources));
      expect(find.text('Victim fit'), findsNothing);
      expect(find.textContaining('Own loss'), findsOneWidget);
      expect(find.text('Fight fit'), findsOneWidget);
    });
  });

  group('U05 inventory groups', () {
    testWidgets(
      'U05 renders eight groups, offline, charges, unresolved, never raw IDs',
      (tester) async {
        final snapshot = AarFitSnapshot(
          snapshotId: 'eight',
          encounterId: 'enc-w6',
          fitting: eightGroupFit(),
          source: AarFitSource.comparisonCapture,
          subject: const AarFitSubject(
            characterId: 42,
            relation: AarFitSubjectRelation.pilot,
          ),
          knowledge: FitInventoryKnowledge(
            groups: {
              for (final group in FitInventoryGroup.values)
                group: FitGroupKnowledge(
                  completeness: InventoryCompleteness.recordedComplete,
                  applicability: GroupApplicability.applicable,
                  unresolvedOccupied: group == FitInventoryGroup.mid
                      ? const [
                          UnresolvedOccupant(
                            sourceEntryKey: 'mid-x',
                            typeId: 92999,
                            group: FitInventoryGroup.mid,
                            label: '',
                          ),
                        ]
                      : const [],
                ),
            },
            unplacedEntries: const [
              UnresolvedOccupant(
                sourceEntryKey: 'unplaced',
                typeId: 92999,
                group: FitInventoryGroup.cargo,
              ),
            ],
          ),
        );
        final entry = AarComparisonSourceEntry(
          id: snapshot.snapshotId,
          role: AarComparisonRole.currentSnapshot,
          snapshot: snapshot,
          label: 'Current snapshot',
        );
        await pumpWorkspace(tester, child: AarFitComparisonCard(entry: entry));
        for (final group in FitInventoryGroup.values) {
          expect(
            find.byKey(Key('aar-fit-group-${group.name}')),
            findsOneWidget,
          );
        }
        expect(find.text('High'), findsOneWidget);
        expect(find.text('Mid'), findsOneWidget);
        expect(find.text('Low'), findsOneWidget);
        expect(find.text('Rigs'), findsOneWidget);
        expect(find.text('Subsystems'), findsOneWidget);
        expect(find.text('Drones'), findsOneWidget);
        expect(find.text('Fighters'), findsOneWidget);
        expect(find.text('Cargo'), findsOneWidget);
        expect(find.textContaining('Offline'), findsWidgets);
        expect(find.text('Cmp Y'), findsWidgets);
        expect(find.text('Unresolved module'), findsWidgets);
        expect(find.textContaining('Type #'), findsNothing);
        expect(find.textContaining('92999'), findsNothing);
        expect(find.textContaining('91601'), findsNothing);
      },
    );
  });

  group('U06 badges and filter', () {
    testWidgets(
      'U06 non-color badges, Show all / Changes only, empty-state copy',
      (tester) async {
        final baseline = AarComparisonFixtures.snapshotOf(
          AarComparisonFixtures.f1Baseline(),
          snapshotId: 'base',
        );
        final target = AarComparisonFixtures.snapshotOf(
          AarComparisonFixtures.f1Target(),
          snapshotId: 'tgt',
        );
        final diff = FitInventoryDiff.compare(baseline, target);
        await pumpWorkspace(
          tester,
          child: workspace(
            sources: AarComparisonSources(
              entries: [
                AarComparisonSourceEntry(
                  id: baseline.snapshotId,
                  role: AarComparisonRole.fightFit,
                  snapshot: baseline,
                  label: 'Fight fit',
                ),
                AarComparisonSourceEntry(
                  id: target.snapshotId,
                  role: AarComparisonRole.currentSnapshot,
                  snapshot: target,
                  label: 'Current snapshot',
                ),
              ],
            ),
            diff: diff,
          ),
        );
        expect(find.text('Added'), findsWidgets);
        expect(find.text('Removed'), findsWidgets);
        expect(find.text('Modified'), findsWidgets);
        expect(find.text('Show all'), findsOneWidget);
        expect(find.text('Changes only'), findsOneWidget);

        final identical = FitInventoryDiff.compare(baseline, baseline);
        await pumpWorkspace(
          tester,
          child: workspace(diff: identical, sources: fourRoleSources()),
        );
        expect(find.text('No recorded equipment changes'), findsOneWidget);
      },
    );
  });

  group('U07 metrics', () {
    testWidgets(
      'U07 F3/F4 metrics at domain precision then formatted, no winner',
      (tester) async {
        expect(F3Oracle.emDeltaEhp, 1500.0);
        expect(F3Oracle.emResistPp, 10.0);
        expect(F3Oracle.emDeltaPercent, 0.25);
        expect(
          AarComparisonMetrics.formatEhp(F3Oracle.emBaselineTotalEhp),
          '6,000',
        );
        expect(
          AarComparisonMetrics.formatEhp(F3Oracle.emTargetTotalEhp),
          '7,500',
        );
        expect(
          AarComparisonMetrics.formatResistPp(F3Oracle.emResistPp),
          '+10 pp',
        );
        expect(F4Oracle.capTransition, 'Depleting → Modeled stable');
        expect(F4Oracle.sustainedLabel, 'Not modeled');

        await pumpWorkspace(
          tester,
          child: workspace(
            baseline: computation(
              totalEhp: F3Oracle.omniBaselineEhp,
              capacitorStable: F4Oracle.baselineTimeToEmptySeconds,
              isCapStable: false,
              dpsTotal: 400,
            ),
            candidate: computation(
              totalEhp: F3Oracle.omniTargetEhp,
              capacitorStable: F4Oracle.candidateStableFraction * 100,
              isCapStable: true,
              dpsTotal: 300,
            ),
          ),
        );
        expect(find.textContaining('6,000'), findsWidgets);
        expect(find.textContaining('7,500'), findsWidgets);
        expect(find.textContaining('+1,500'), findsWidgets);
        expect(find.textContaining('+10 pp'), findsOneWidget);
        expect(find.text('Depleting → Modeled stable'), findsOneWidget);
        expect(find.textContaining('100'), findsWidgets);
        expect(find.textContaining('20'), findsWidgets);
        expect(find.text('Not modeled'), findsOneWidget);
        expect(find.textContaining('Winner'), findsNothing);
        expect(find.text('Best fit'), findsNothing);
        expect(find.textContaining('Unavailable'), findsNothing);
      },
    );
  });

  group('U08 BOM card', () {
    testWidgets(
      'U08 Changes vs Full replacement, header, removals, unquantified',
      (tester) async {
        final baseline = AarComparisonFixtures.snapshotOf(
          AarComparisonFixtures.f2Baseline(),
          snapshotId: 'f2-base',
        );
        final target = AarComparisonFixtures.snapshotOf(
          AarComparisonFixtures.f2Target(),
          snapshotId: 'f2-tgt',
        );
        final changes = FitBillOfMaterials.fromSnapshots(
          baseline: baseline,
          target: target,
        );
        await pumpWorkspace(
          tester,
          child: AarFitBomView(
            bom: changes,
            targetLabel: 'F2 Target',
            baselineLabel: 'F2 Baseline',
          ),
        );
        expect(find.text('Changes'), findsWidgets);
        expect(find.text('Full replacement'), findsWidgets);
        expect(find.textContaining('F2 Target'), findsWidgets);
        expect(find.textContaining('F2 Baseline'), findsWidgets);
        expect(find.textContaining('Cmp C'), findsWidgets);
        expect(find.textContaining('Cmp B'), findsWidgets);
        expect(find.textContaining('Removals'), findsWidgets);
        expect(
          find.textContaining('Charge quantity not recorded'),
          findsWidgets,
        );
      },
    );
  });

  group('U09 BOM annotations', () {
    testWidgets('U09 priced subtotal, coverage, spares, shortfall, freshness', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 9, 15, 12);
      final baseline = AarComparisonFixtures.snapshotOf(
        AarComparisonFixtures.f2Baseline(),
        snapshotId: 'f2-base',
      );
      final target = AarComparisonFixtures.snapshotOf(
        AarComparisonFixtures.f2Target(),
        snapshotId: 'f2-tgt',
      );
      final bom = FitBillOfMaterials.fromSnapshots(
        baseline: baseline,
        target: target,
      );
      final priced = const AarBomPricer().price(
        bom: bom,
        estimates: [
          AarPriceEstimate.fromQuote(
            AarMarketQuote(
              typeId: kCmpModuleC,
              averagePrice: F2Oracle.cPrice.toDouble(),
              lastUpdated: now,
            ),
            now: now,
          ),
          AarPriceEstimate.fromQuote(
            AarMarketQuote(
              typeId: kCmpAmmo,
              averagePrice: F2Oracle.ammoPrice.toDouble(),
              lastUpdated: now,
            ),
            now: now,
          ),
          AarPriceEstimate.fromQuote(
            AarMarketQuote(
              typeId: kCmpPaste,
              adjustedPrice: 5,
              lastUpdated: now,
            ),
            now: now,
          ),
        ],
      );
      expect(priced.heading, 'Priced subtotal');
      expect(priced.amount.asDouble, F2Oracle.changesPricedSubtotal);

      const matcher = AarSpareMatcher();
      final stock = [
        AarCachedAsset(
          itemId: 10,
          characterId: 42,
          typeId: kCmpModuleC,
          locationId: 60003760,
          locationFlag: 'Hangar',
          quantity: 1,
        ),
        AarCachedAsset(
          itemId: 11,
          characterId: 42,
          typeId: kCmpAmmo,
          locationId: 60003760,
          locationFlag: 'Hangar',
          quantity: 30,
        ),
        AarCachedAsset(
          itemId: 12,
          characterId: 42,
          typeId: kCmpPaste,
          locationId: 60003760,
          locationFlag: 'Hangar',
          quantity: 5,
        ),
      ];
      final matches = [
        matcher.match(
          typeId: kCmpModuleC,
          requiredCount: 1,
          encounterCharacterId: 42,
          selectedLocationId: 60003760,
          assets: stock,
        ),
        matcher.match(
          typeId: kCmpAmmo,
          requiredCount: 50,
          encounterCharacterId: 42,
          selectedLocationId: 60003760,
          assets: stock,
        ),
        matcher.match(
          typeId: kCmpPaste,
          requiredCount: 20,
          encounterCharacterId: 42,
          selectedLocationId: 60003760,
          assets: stock,
        ),
      ];

      await pumpWorkspace(
        tester,
        child: AarFitBomView(bom: bom, priced: priced, matches: matches),
      );
      expect(find.text('Priced subtotal'), findsOneWidget);
      expect(find.textContaining('2,000,500'), findsWidgets);
      expect(find.textContaining('2/3'), findsWidgets);
      expect(find.text('Total cost'), findsNothing);
      expect(find.textContaining('Asset freshness unknown'), findsWidgets);
      expect(find.textContaining('20'), findsWidgets);
      expect(formatIsk(priced.amount.asDouble), contains('2,000,500'));
    });
  });

  group('U10 profile selector', () {
    testWidgets(
      'U10 Omni is default; M5 incoming and aggregate are offered; no ledger watch',
      (tester) async {
        var correlationWatches = 0;
        await pumpWorkspace(
          tester,
          child: workspace(onWatchCorrelation: () => correlationWatches++),
        );
        final selector = tester.widget<DropdownButton<String>>(
          find.byKey(const Key('aar-comparison-profile-selector')),
        );
        expect(selector.value, 'omni');
        expect(correlationWatches, 0);
        await tester.tap(
          find.byKey(const Key('aar-comparison-profile-selector')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Incoming allocation'), findsWidgets);
        expect(find.text('Aggregate blend'), findsWidgets);
      },
    );
  });

  group('U11 capture feedback', () {
    testWidgets('U11 capture snackbars match §8.4 exactly', (tester) async {
      Future<void> expectMessage({
        AarComparisonFailureCode? code,
        required String expected,
      }) async {
        await pumpWorkspace(
          tester,
          child: workspace(
            onCaptureCurrent: () async => AarComparisonSaveResult(
              status: code == null
                  ? AarComparisonSaveStatus.written
                  : AarComparisonSaveStatus.failed,
              code: code,
            ),
          ),
        );
        await tester.tap(
          find.byKey(const Key('aar-comparison-capture-current')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text(expected), findsOneWidget);
      }

      await expectMessage(expected: 'Current fit saved for comparison.');
      await expectMessage(
        code: AarComparisonFailureCode.authUnavailable,
        expected: 'Sign in with this pilot to capture the current fit.',
      );
      await expectMessage(
        code: AarComparisonFailureCode.noShip,
        expected: 'No active ship is available for this pilot.',
      );
      await expectMessage(
        code: AarComparisonFailureCode.captureFailure,
        expected: 'Could not save the current fit for comparison. Try again.',
      );
    });
  });

  group('U12 proposal dialog', () {
    testWidgets(
      'U12 stays open on error with inline copy and isSubmitting CAS',
      (tester) async {
        var calls = 0;
        final gate = Completer<AarComparisonSaveResult>();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        routeSettings: const RouteSettings(
                          name: AarProposalDialog.routeName,
                        ),
                        builder: (_) => AarProposalDialog(
                          savedReferences: [
                            SavedFittingReference(
                              id: 'saved-1',
                              fitting: AarComparisonFixtures.hullOnly(),
                              createdAt: recordedAt,
                              updatedAt: recordedAt,
                            ),
                          ],
                          onImportEft: (eft) async {
                            calls += 1;
                            if (!gate.isCompleted) {
                              return gate.future;
                            }
                            return const AarComparisonSaveResult(
                              status: AarComparisonSaveStatus.rejected,
                              code: AarComparisonFailureCode.invalidProposal,
                              message: 'Invalid EFT',
                            );
                          },
                        ),
                      );
                    },
                    child: const Text('Open proposal'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open proposal'));
        await tester.pump();
        expect(find.byKey(const Key('aar-proposal-dialog')), findsOneWidget);
        expect(find.byKey(const Key('aar-proposal-eft-field')), findsOneWidget);
        expect(
          find.byKey(const Key('aar-proposal-saved-picker')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('aar-proposal-eft-field')),
          'not-eft',
        );
        await tester.tap(find.byKey(const Key('aar-proposal-submit')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('aar-proposal-submit')));
        await tester.pump();
        expect(calls, 1);

        gate.complete(
          const AarComparisonSaveResult(
            status: AarComparisonSaveStatus.rejected,
            code: AarComparisonFailureCode.invalidProposal,
            message: 'Invalid EFT',
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('aar-proposal-dialog')), findsOneWidget);
        expect(find.byKey(const Key('aar-proposal-error')), findsOneWidget);
        expect(find.textContaining('Invalid EFT'), findsOneWidget);
      },
    );
  });

  group('U13 origin disclosure', () {
    testWidgets('U13 earlier-fit warning and unstructured candidate copy', (
      tester,
    ) async {
      final target = AarComparisonFixtures.snapshotOf(
        AarComparisonFixtures.f1Target(),
        snapshotId: 'proposed',
      );
      final earlier = AarFitProposal(
        proposalId: 'p-old',
        origin: AarProposalOrigin.ai,
        encounterId: 'enc-w6',
        baselineSnapshotId: 'f-old',
        target: target,
      );
      await pumpWorkspace(
        tester,
        child: workspace(proposal: earlier, currentBaselineSnapshotId: 'f-new'),
      );
      expect(find.text('Based on an earlier fit.'), findsOneWidget);

      final unstructured = AarFitProposal(
        proposalId: 'p-legacy',
        origin: AarProposalOrigin.ai,
        encounterId: 'enc-w6',
        status: AarProposalValidationStatus.invalid,
      );
      await pumpWorkspace(tester, child: workspace(proposal: unstructured));
      expect(find.text('No structured proposed fit.'), findsOneWidget);
    });
  });

  group('U14 price refresh', () {
    testWidgets('U14 price refresh snackbars match §8.4 exactly', (
      tester,
    ) async {
      Future<void> expectMessage({
        required bool success,
        required bool hasCache,
        required String expected,
      }) async {
        await pumpWorkspace(
          tester,
          child: workspace(
            priceRefreshHasCache: hasCache,
            onRefreshPrices: () async => AarComparisonSaveResult(
              status: success
                  ? AarComparisonSaveStatus.written
                  : AarComparisonSaveStatus.failed,
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('aar-comparison-price-refresh')));
        await tester.pump();
        expect(find.text(expected), findsOneWidget);
      }

      await expectMessage(
        success: true,
        hasCache: true,
        expected: 'Price estimates refreshed.',
      );
      await expectMessage(
        success: false,
        hasCache: true,
        expected: 'Could not refresh prices. Showing cached estimates.',
      );
      await expectMessage(
        success: false,
        hasCache: false,
        expected: 'Could not refresh prices. Price estimates are unavailable.',
      );
    });
  });

  group('U15 isolation', () {
    late FitEvidenceHarness harness;

    setUp(() async {
      harness = FitEvidenceHarness();
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    testWidgets(
      'U15 opening comparison or switching profiles does not mutate ledger',
      (tester) async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        await harness.enrichmentService.importPilotFit(
          encounter,
          '[Rifter, Test]\n',
        );
        final before = jsonEncode(
          (await harness.repository.loadEnrichment(encounter.id))!.toJson(),
        );
        var correlationWatches = 0;
        var profileChanges = 0;
        await pumpWorkspace(
          tester,
          child: workspace(
            selectedProfileId: 'omni',
            onWatchCorrelation: () => correlationWatches++,
            onProfileChanged: (_) => profileChanges++,
          ),
        );
        expect(correlationWatches, 0);
        await tester.tap(
          find.byKey(const Key('aar-comparison-profile-selector')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Incoming allocation').last);
        await tester.pump();
        expect(profileChanges, 1);
        final after = jsonEncode(
          (await harness.repository.loadEnrichment(encounter.id))!.toJson(),
        );
        expect(after, before);
        expect(harness.codex.calls, 0);
      },
    );
  });

  group('U16 lifecycle', () {
    testWidgets('U16 disposing during capture does not snackbar or throw', (
      tester,
    ) async {
      final allow = Completer<AarComparisonSaveResult>();
      await pumpWorkspace(
        tester,
        child: workspace(onCaptureCurrent: () => allow.future),
      );
      await tester.tap(find.byKey(const Key('aar-comparison-capture-current')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      allow.complete(
        const AarComparisonSaveResult(status: AarComparisonSaveStatus.written),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Current fit saved for comparison.'), findsNothing);
    });
  });
}
