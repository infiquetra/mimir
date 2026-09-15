import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/theme/eve_colors.dart';
import 'package:mimir/features/combat_analyzer/data/combat_damage_profile_resolver.dart';
import 'package:mimir/features/combat_analyzer/data/combat_providers.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_assessment.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_scorer.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_profile.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_evidence_checklist_card.dart';

import '../fixtures/aar_evidence_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group F — AarEvidenceChecklistCard', () {
    late AarEvidenceActionHandlers handlers;
    late List<String> calls;

    setUp(() {
      calls = <String>[];
      handlers = AarEvidenceActionHandlers(
        onUseCurrentFit: () => calls.add('use'),
        onImportFit: () => calls.add('import'),
        onSearchKillmails: () => calls.add('search'),
        onReauthorize: () => calls.add('reauth'),
      );
    });

    AarEvidenceAssessment s1() => const AarEvidenceScorer().assess(s1Inputs());
    AarEvidenceAssessment s6() => const AarEvidenceScorer().assess(s6Inputs());
    AarEvidenceAssessment s7() => const AarEvidenceScorer().assess(s7Inputs());

    AarEvidenceAssessment score20() => AarEvidenceScorer.combine(
      rows(
        d1: AarEvidenceStatus.missing,
        d2: AarEvidenceStatus.complete,
        d3: AarEvidenceStatus.missing,
        d4: AarEvidenceStatus.missing,
        d5: AarEvidenceStatus.missing,
      ),
    );

    Future<void> pumpBody(
      WidgetTester tester,
      AarEvidenceAssessment assessment, {
      AarEvidenceActionHandlers? handlersOverride,
      bool collapsed = false,
    }) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AarEvidenceChecklistBody(
                assessment: assessment,
                handlers: handlersOverride ?? handlers,
                collapsed: collapsed,
                onToggle: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> pumpCard(
      WidgetTester tester, {
      required ParsedCombatEncounter encounter,
      required List<dynamic> overrides,
      AarEvidenceActionHandlers? handlersOverride,
    }) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...overrides],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AarEvidenceChecklistCard(
                  encounter: encounter,
                  handlers: handlersOverride ?? handlers,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Finder rowKey(AarEvidenceDimension d) =>
        find.byKey(Key('aar-evidence-row-${d.name}'));

    testWidgets('T6.1 renders five rows for a fully-scored assessment', (
      tester,
    ) async {
      await pumpBody(tester, s1());
      for (final dimension in AarEvidenceDimension.values) {
        expect(rowKey(dimension), findsOneWidget);
      }
    });

    testWidgets('T6.2 row order matches AC2.2', (tester) async {
      await pumpBody(tester, s1());
      const order = [
        AarEvidenceDimension.pilotFit,
        AarEvidenceDimension.damageProfile,
        AarEvidenceDimension.opponentFit,
        AarEvidenceDimension.combatLog,
        AarEvidenceDimension.opponentIdentity,
      ];
      final dys = [
        for (final dimension in order) tester.getTopLeft(rowKey(dimension)).dy,
      ];
      for (var i = 1; i < dys.length; i++) {
        expect(
          dys[i],
          greaterThan(dys[i - 1]),
          reason: '${order[i].name} should sit below ${order[i - 1].name}',
        );
      }
    });

    testWidgets(
      'T6.3 Missing pilot-fit row renders Use Current Fit and Import Fit',
      (tester) async {
        await pumpBody(tester, s1());
        final use = find.byKey(
          const Key('aar-evidence-action-useCurrentFit-pilotFit'),
        );
        final import = find.byKey(
          const Key('aar-evidence-action-importFit-pilotFit'),
        );
        expect(use, findsOneWidget);
        expect(import, findsOneWidget);
        await tester.tap(use);
        await tester.pump();
        await tester.tap(import);
        await tester.pump();
        expect(calls, ['use', 'import']);
      },
    );

    testWidgets('T6.4 Complete pilot-fit row renders no buttons', (
      tester,
    ) async {
      await pumpBody(tester, s7());
      expect(
        find.descendant(
          of: rowKey(AarEvidenceDimension.pilotFit),
          matching: find.byType(OutlinedButton),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'T6.5 Unavailable row renders no buttons and shows its reason',
      (tester) async {
        await pumpBody(tester, s6());
        expect(
          find.descendant(
            of: rowKey(AarEvidenceDimension.opponentIdentity),
            matching: find.byType(OutlinedButton),
          ),
          findsNothing,
        );
        expect(
          find.text('No ESI or zKill killmail matched this encounter.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('T6.6 point projection renders on Missing rows', (
      tester,
    ) async {
      await pumpBody(tester, s1());
      expect(
        find.byKey(const Key('aar-evidence-gain-pilotFit')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('aar-evidence-gain-pilotFit')),
          matching: find.text('+30 pts'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('aar-evidence-gain-combatLog')),
        findsNothing,
      );
    });

    testWidgets('T6.7 at 100% the list is collapsed; tapping expands it', (
      tester,
    ) async {
      final inputs = s7Inputs();
      await pumpCard(
        tester,
        encounter: inputs.encounter,
        overrides: [
          aarEvidenceAssessmentProvider.overrideWith(
            (ref, enc) async => const AarEvidenceScorer().assess(inputs),
          ),
        ],
      );
      for (final dimension in AarEvidenceDimension.values) {
        expect(rowKey(dimension), findsNothing);
      }
      expect(find.byKey(const Key('aar-evidence-toggle')), findsOneWidget);
      await tester.tap(find.byKey(const Key('aar-evidence-toggle')));
      await tester.pump();
      for (final dimension in AarEvidenceDimension.values) {
        expect(rowKey(dimension), findsOneWidget);
      }
    });

    testWidgets('T6.8 loading renders the skeleton, not a bare spinner', (
      tester,
    ) async {
      final encounter = encounterWith();
      final pending = Completer<AarEvidenceAssessment>();
      addTearDown(() {
        if (!pending.isCompleted) {
          pending.complete(s1());
        }
      });
      await pumpCard(
        tester,
        encounter: encounter,
        overrides: [
          aarEvidenceAssessmentProvider.overrideWith(
            (ref, enc) => pending.future,
          ),
        ],
      );
      expect(find.byKey(const Key('aar-evidence-skeleton')), findsOneWidget);
      expect(find.text('Assessing evidence…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, isNull);
    });

    testWidgets('T6.9 error renders the card without throwing', (tester) async {
      final encounter = encounterWith();
      await pumpCard(
        tester,
        encounter: encounter,
        overrides: [
          aarEvidenceAssessmentProvider.overrideWith(
            (ref, enc) => Future<AarEvidenceAssessment>.error(
              StateError('assessment failed'),
            ),
          ),
        ],
      );
      expect(find.text('Evidence assessment unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T6.10 Known limits section renders the range entry', (
      tester,
    ) async {
      await pumpBody(tester, s1());
      expect(find.byKey(const Key('aar-evidence-limits')), findsOneWidget);
      expect(
        find.text('Engagement range is not recorded in EVE combat logs.'),
        findsOneWidget,
      );
    });

    testWidgets('T6.11 progress bar colour matches the band', (tester) async {
      Color progressColor() {
        return tester
            .widget<LinearProgressIndicator>(
              find.byKey(const Key('aar-evidence-progress')),
            )
            .color!;
      }

      await pumpBody(tester, s1());
      expect(progressColor(), EveColors.warning);

      await pumpBody(tester, s7());
      expect(progressColor(), EveColors.success);

      await pumpBody(tester, score20());
      expect(progressColor(), EveColors.error);
    });

    testWidgets('F.12 buttons are hidden when the handler is null', (
      tester,
    ) async {
      await pumpBody(
        tester,
        s1(),
        handlersOverride: const AarEvidenceActionHandlers(),
      );
      expect(find.byType(OutlinedButton), findsNothing);
      expect(rowKey(AarEvidenceDimension.pilotFit), findsOneWidget);
    });

    testWidgets('F.13 previous assessment stays visible during a reload', (
      tester,
    ) async {
      final inputs = s1Inputs();
      final encounter = inputs.encounter;
      final holder = _Holder(inputs);
      await pumpCard(
        tester,
        encounter: encounter,
        overrides: _upstreamOverrides(holder),
      );
      expect(find.text('49%'), findsWidgets);
      expect(find.byKey(const Key('aar-evidence-skeleton')), findsNothing);

      holder.enrichment = enrichment(
        parsedEncounterId: encounter.id,
        victimFitEvidence: holder.enrichment?.victimFitEvidence,
        pilotFitEvidence: fitEvidence(),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AarEvidenceChecklistCard)),
      );
      container.invalidate(combatEnrichmentProvider(encounter.id));
      await tester.pump();
      expect(find.text('49%'), findsWidgets);
      expect(find.byKey(const Key('aar-evidence-skeleton')), findsNothing);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('79%'), findsWidgets);
    });

    testWidgets('F.14 each row shows icon, name, status word, and detail', (
      tester,
    ) async {
      final assessment = s1();
      await pumpBody(tester, assessment);
      for (final row in assessment.ordered) {
        final finder = rowKey(row.dimension);
        expect(finder, findsOneWidget);
        expect(
          find.descendant(of: finder, matching: find.byType(Icon)),
          findsWidgets,
        );
        expect(
          find.descendant(of: finder, matching: find.text(row.dimension.label)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: finder, matching: find.text(row.status.label)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: finder, matching: find.text(row.detail)),
          findsOneWidget,
        );
      }
    });
  });
}

class _Holder {
  _Holder(AarEvidenceInputs s1)
    : enrichment = s1.enrichment,
      bundle = AarDerivationBundle(
        self: derivation(),
        opponent: s1.bundle.opponent,
      ),
      incoming = s1.incoming,
      outgoing = s1.outgoing;

  CombatEnrichment? enrichment;
  AarDerivationBundle bundle;
  CombatDamageProfile incoming;
  CombatDamageProfile outgoing;
}

List<dynamic> _upstreamOverrides(_Holder holder) {
  return [
    combatEnrichmentProvider.overrideWith((ref, id) async => holder.enrichment),
    aarFitDerivationsProvider.overrideWith((ref, enc) async => holder.bundle),
    combatIncomingDamageProfileProvider.overrideWith(
      (ref, enc) async => holder.incoming,
    ),
    combatDamageProfileProvider.overrideWith(
      (ref, enc) async => holder.outgoing,
    ),
    aarIncomingMatchupsProvider.overrideWith(
      (ref, enc) => AarIncomingMatchupState(
        encounterId: enc.id,
        allocationRequestKey: 'test',
        identityRequestKey: 'id',
        allocationStatus: AarIncomingDependencyStatus.ready,
        correlationStatus: AarIncomingDependencyStatus.ready,
        classificationStatus: AarIncomingDependencyStatus.ready,
        defenseStatus: AarIncomingDependencyStatus.ready,
      ),
    ),
  ];
}
