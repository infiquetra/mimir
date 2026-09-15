import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_attacker_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_attacker_matchup_deriver.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocation.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocator.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/combat_analyzer/domain/tank_classifier.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_attacker_matchup_card.dart';
import 'package:mimir/features/wallet/data/wallet_providers.dart';

import '../fixtures/attacker_matchup_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AarAttackerMatchupCard U04–U06 U09', () {
    nameOverrides({bool failShips = false}) => [
      itemNameProvider.overrideWith((ref, id) async {
        if (failShips) {
          throw StateError('name lookup failed');
        }
        return switch (id) {
          24702 => 'Hurricane',
          34828 => 'Jackdaw',
          587 => 'Rifter',
          _ => 'Unknown ship',
        };
      }),
    ];

    Future<void> pumpCard(
      WidgetTester tester, {
      required AarAttackerMatchup matchup,
      required String encounterId,
      bool expanded = true,
      bool failShips = false,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: nameOverrides(failShips: failShips),
          child: MaterialApp(
            home: Scaffold(
              body: AarAttackerMatchupCard(
                matchup: matchup,
                encounterId: encounterId,
                expanded: expanded,
                onToggle: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('U04 S4 victory uses pilot defense and Your EHP vs victim name', (
      tester,
    ) async {
      final s4 = s4Victory();
      final bundle = deriveUiBundle(s4);
      final card = bundle.attackers.single;
      await pumpCard(tester, matchup: card, encounterId: bundle.encounterId);
      expect(find.textContaining('Your EHP vs Vex Kalari'), findsOneWidget);
      expect(find.textContaining('Jackdaw'), findsNothing);
      expect(find.textContaining('Your EHP vs Pilot'), findsNothing);
      expect(
        find.byKey(
          Key(
            'aar-incoming-${bundle.encounterId}-${card.source.allocation.sourceId}-ehp',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('U05 S5 mixed weapons render a 60/40 type split', (
      tester,
    ) async {
      final s5 = s5MixedWeapons();
      final bundle = deriveUiBundle(s5);
      final card = bundle.attackers.single;
      await pumpCard(tester, matchup: card, encounterId: bundle.encounterId);
      final split = find.byKey(
        Key(
          'aar-incoming-${bundle.encounterId}-${card.source.allocation.sourceId}-split',
        ),
      );
      expect(split, findsOneWidget);
      final text = tester
          .widgetList<Text>(
            find.descendant(of: split, matching: find.byType(Text)),
          )
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
          .join(' ');
      expect(text, contains('60'));
      expect(text, contains('40'));
      expect(text, contains('100.0%'));
    });

    testWidgets(
      'U06 zero coverage has no EHP; partial coverage is Resolved portion only',
      (tester) async {
        final zero = s1Solo();
        final zeroBundle = deriveUiBundle(
          zero,
          extraWeapons: {
            normalizeCombatName(artemAutocannonName): unresolvedWeapon(
              artemAutocannonName,
              status: WeaponResolutionStatus.noExactType,
            ),
          },
        );
        await pumpCard(
          tester,
          matchup: zeroBundle.attackers.single,
          encounterId: zeroBundle.encounterId,
        );
        expect(find.text('Damage types unresolved'), findsOneWidget);
        expect(
          find.byKey(
            Key(
              'aar-incoming-${zeroBundle.encounterId}-${zeroBundle.attackers.single.source.allocation.sourceId}-ehp',
            ),
          ),
          findsNothing,
        );

        final partial = s1Solo(partialUnknownWeapon: true);
        final partialBundle = deriveUiBundle(partial);
        await pumpCard(
          tester,
          matchup: partialBundle.attackers.single,
          encounterId: partialBundle.encounterId,
        );
        expect(find.textContaining('Resolved portion only'), findsOneWidget);
        expect(
          find.byKey(
            Key(
              'aar-incoming-${partialBundle.encounterId}-${partialBundle.attackers.single.source.allocation.sourceId}-ehp',
            ),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('omni'), findsNothing);
      },
    );

    testWidgets(
      'U09 ship lookup error shows Unknown ship and never Type # or aN',
      (tester) async {
        final s2 = s2Fleet();
        final bundle = deriveUiBundle(s2);
        final kite = bundle.attackers.firstWhere(
          (a) => a.source.allocation.rawActorName == 'Kite Mondeo',
        );
        await pumpCard(
          tester,
          matchup: kite,
          encounterId: bundle.encounterId,
          failShips: true,
        );
        expect(find.text('Unknown ship'), findsWidgets);
        expect(find.textContaining('Type #'), findsNothing);
        expect(find.textContaining('Type #34828'), findsNothing);
        expect(find.textContaining('a0'), findsNothing);
        expect(find.textContaining('Logged as Kite Mondeo'), findsOneWidget);
        final semantics = tester.getSemantics(
          find.byType(AarAttackerMatchupCard),
        );
        expect(semantics.label, isNot(contains('34828')));
      },
    );

    testWidgets('U04 unknown layer keeps EHP without a hole', (tester) async {
      final s1 = s1Solo();
      final bundle = deriveUiBundle(
        s1,
        fit: fixtureAPilotFit(
          tank: const TankAssessment(
            layer: TankLayer.unknown,
            mode: TankMode.unfitted,
            shieldBoostHps: 0,
            armorRepairHps: 0,
            hullRepairHps: 0,
            shieldGainEhp: 0,
            armorGainEhp: 0,
            hullGainEhp: 0,
            reasoning: 'unknown',
          ),
        ),
      );
      await pumpCard(
        tester,
        matchup: bundle.attackers.single,
        encounterId: bundle.encounterId,
      );
      expect(
        find.byKey(
          Key(
            'aar-incoming-${bundle.encounterId}-${bundle.attackers.single.source.allocation.sourceId}-ehp',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          Key(
            'aar-incoming-${bundle.encounterId}-${bundle.attackers.single.source.allocation.sourceId}-hole',
          ),
        ),
        findsNothing,
      );
    });
  });
}

AarIncomingMatchupBundle deriveUiBundle(
  ({
    ParsedCombatEncounter encounter,
    EsiKillmailDetail detail,
    AttackerCorrelation correlation,
    CombatEnrichment enrichment,
  })
  scenario, {
  AarFitDerivation? fit,
  Map<String, IncomingWeaponResolution> extraWeapons = const {},
}) {
  final result = IncomingDamageAllocator.allocate(
    encounter: scenario.encounter,
    weapons: matchupWeaponTable(extraWeapons),
    sdeContentKey: matchupSdeContentKey,
  );
  final allocation = (result as IncomingAllocationReady).allocation;
  return AarAttackerMatchupDeriver.derive(
    allocation: allocation,
    correlation: matchupCorrelationContext(
      encounter: scenario.encounter,
      detail: scenario.detail,
      correlation: scenario.correlation,
    ),
    pilotFit: fit ?? fixtureAPilotFit(),
    pilotFitEvidence: fixtureAPilotFitEvidence(),
    pilotFitKey: 'fit-a',
    dependencyLimitations: const [],
  );
}
