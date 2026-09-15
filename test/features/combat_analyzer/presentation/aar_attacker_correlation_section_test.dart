import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/theme/eve_colors.dart';
import 'package:mimir/features/combat_analyzer/data/combat_providers.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_matchup.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_attacker_correlation_section.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_matchup_section.dart';
import 'package:mimir/features/fitting/domain/damage_pattern.dart';
import 'package:mimir/features/wallet/data/wallet_providers.dart';

import '../fixtures/attacker_correlation_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group H — AarAttackerCorrelationSection', () {
    nameOverrides() => [
      itemNameProvider.overrideWith((ref, id) async {
        return switch (id) {
          24702 => 'Hurricane',
          34828 => 'Jackdaw',
          22456 => 'Sabre',
          587 => 'Rifter',
          30001 => 'Serpentis Watchman',
          _ => 'Type #$id',
        };
      }),
    ];

    Future<void> pumpBody(
      WidgetTester tester, {
      required AttackerCorrelation? correlation,
      required Map<String, int> incomingBySource,
      List extraOverrides = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...nameOverrides(), ...extraOverrides],
          child: MaterialApp(
            home: Scaffold(
              body: AarAttackerCorrelationBody(
                correlation: correlation,
                incomingBySource: incomingBySource,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    String textsUnder(WidgetTester tester, Key key) {
      return tester
          .widgetList<Text>(
            find.descendant(of: find.byKey(key), matching: find.byType(Text)),
          )
          .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
          .join(' ');
    }

    testWidgets('T8.1 correlated rows render badge, ship, damage, signals', (
      tester,
    ) async {
      final s2 = s2Loss();
      await pumpBody(
        tester,
        correlation: correlate(s2),
        incomingBySource: s2.encounter.aggregates.incomingBySource,
      );
      final row = find.byKey(const Key('aar-attacker-row-a0'));
      expect(row, findsOneWidget);
      final text = textsUnder(tester, const Key('aar-attacker-row-a0'));
      expect(text, contains('Artem S3'));
      expect(text, contains('Hurricane'));
      expect(text, contains('4,200'));
      expect(text, contains('Confirmed'));
      expect(text, contains('name match'));
      expect(text, contains('damage proportion'));
    });

    testWidgets('T8.2 badge colours map per §7.2', (tester) async {
      final correlation = AttackerCorrelation(
        killmailId: 1,
        selfIsVictim: true,
        correlated: [
          CorrelatedAttacker(
            actor: actor('Alice'),
            participant: participant(key: 'a0', name: 'Alice'),
            confidence: AttackerCorrelationConfidence.confirmed,
            score: 0.9,
            signals: const [CorrelationSignal.name],
          ),
          CorrelatedAttacker(
            actor: actor('Bob', damage: 500),
            participant: participant(key: 'a1', characterId: 9002, name: 'Bob'),
            confidence: AttackerCorrelationConfidence.probable,
            score: 0.5,
            signals: const [CorrelationSignal.ship],
          ),
          CorrelatedAttacker(
            actor: actor('Carol', damage: 400),
            participant: participant(
              key: 'a2',
              characterId: 9003,
              name: 'Carol',
            ),
            confidence: AttackerCorrelationConfidence.possible,
            score: 0.3,
            signals: const [CorrelationSignal.weapon],
          ),
        ],
        unattributedActors: const [],
        uncorrelatedParticipants: [
          participant(key: 'a3', characterId: 9004, name: 'Dave'),
        ],
        correlatedIncomingDamage: 1900,
        unattributedIncomingDamage: 0,
        npcIncomingDamage: 0,
        totalIncomingDamage: 1900,
        reasons: const {'participant:a3': UncorrelatedReason.noLogPresence},
        correlatedAt: now,
      );
      await pumpBody(
        tester,
        correlation: correlation,
        incomingBySource: const {'Alice': 1000, 'Bob': 500, 'Carol': 400},
      );

      Icon badgeIcon(String key) {
        return tester.widget<Icon>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Icon),
          ),
        );
      }

      expect(find.byKey(const Key('aar-attacker-badge-a0')), findsOneWidget);
      expect(badgeIcon('aar-attacker-badge-a0').icon, Icons.check_circle);
      expect(badgeIcon('aar-attacker-badge-a0').color, EveColors.success);

      expect(find.byKey(const Key('aar-attacker-badge-a1')), findsOneWidget);
      expect(badgeIcon('aar-attacker-badge-a1').icon, Icons.help_outline);
      expect(badgeIcon('aar-attacker-badge-a1').color, EveColors.warning);

      expect(find.byKey(const Key('aar-attacker-badge-a2')), findsOneWidget);
      expect(badgeIcon('aar-attacker-badge-a2').icon, Icons.warning_amber);
      expect(badgeIcon('aar-attacker-badge-a2').color, EveColors.warning);

      final toggle = find.byKey(const Key('aar-attackers-uncorrelated-toggle'));
      expect(toggle, findsOneWidget);
      await tester.tap(toggle);
      await tester.pump();
      expect(find.byIcon(Icons.remove_circle_outline), findsWidgets);
      final uncorrelated = tester.widget<Icon>(
        find.byIcon(Icons.remove_circle_outline).first,
      );
      expect(uncorrelated.color, EveColors.textSecondary);
    });

    testWidgets('T8.3 uncorrelated list collapsed but expandable', (
      tester,
    ) async {
      final s2 = s2Loss();
      await pumpBody(
        tester,
        correlation: correlate(s2),
        incomingBySource: s2.encounter.aggregates.incomingBySource,
      );
      final toggle = find.byKey(const Key('aar-attackers-uncorrelated-toggle'));
      expect(toggle, findsOneWidget);
      expect(
        textsUnder(tester, const Key('aar-attackers-uncorrelated-toggle')),
        contains('1 attacker not present in your combat log'),
      );
      expect(find.text('Pell Ivo'), findsNothing);
      await tester.tap(toggle);
      await tester.pump();
      expect(find.text('Pell Ivo'), findsOneWidget);
    });

    testWidgets('T8.4 NPC and unattributed rows render distinctly', (
      tester,
    ) async {
      final s5 = s5NpcMix();
      await pumpBody(
        tester,
        correlation: correlate(s5),
        incomingBySource: s5.encounter.aggregates.incomingBySource,
      );
      expect(find.byKey(const Key('aar-attackers-npc')), findsOneWidget);
      expect(
        textsUnder(tester, const Key('aar-attackers-npc')),
        contains('1,400'),
      );

      final s4 = s4ThirdParty();
      await pumpBody(
        tester,
        correlation: correlate(s4),
        incomingBySource: s4.encounter.aggregates.incomingBySource,
      );
      expect(
        find.byKey(const Key('aar-attackers-unattributed')),
        findsOneWidget,
      );
      final unattributed = textsUnder(
        tester,
        const Key('aar-attackers-unattributed'),
      );
      expect(unattributed, contains('1,100'));
      expect(unattributed, contains('Kite Mondeo — not on the killmail'));
    });

    testWidgets(
      'T8.5 null correlation renders plain actors, no badges, no counts',
      (tester) async {
        await pumpBody(
          tester,
          correlation: null,
          incomingBySource: const {'Artem S3': 300},
        );
        expect(find.byKey(const Key('aar-actor-row-artem s3')), findsOneWidget);
        expect(find.text('Confirmed'), findsNothing);
        expect(find.text('Probable'), findsNothing);
        expect(find.textContaining('0 identified'), findsNothing);
        expect(find.text('Incoming Sources'), findsOneWidget);
      },
    );

    testWidgets('T8.6 ship names resolve via itemNameProvider', (tester) async {
      final s2 = s2Loss();
      await pumpBody(
        tester,
        correlation: correlate(s2),
        incomingBySource: s2.encounter.aggregates.incomingBySource,
        extraOverrides: [
          itemNameProvider(24702).overrideWith((ref) async => 'Hurricane'),
        ],
      );
      expect(find.text('Hurricane'), findsWidgets);
      expect(find.text('Type #24702'), findsNothing);

      await pumpBody(
        tester,
        correlation: correlate(s2),
        incomingBySource: s2.encounter.aggregates.incomingBySource,
        extraOverrides: [
          itemNameProvider(24702).overrideWith((ref) async {
            throw StateError('name lookup failed');
          }),
        ],
      );
      expect(find.text('Type #24702'), findsOneWidget);
      expect(find.text('Hurricane'), findsNothing);
    });

    testWidgets('T8.7 loading and error states via .when()', (tester) async {
      final s2 = s2Loss();
      final pending = Completer<AttackerCorrelation?>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...nameOverrides(),
            combatAttackerCorrelationProvider.overrideWith(
              (ref, encounter) => pending.future,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AarAttackerCorrelationSection(encounter: s2.encounter),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('aar-attackers-loading')), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...nameOverrides(),
            combatAttackerCorrelationProvider.overrideWith((ref, encounter) {
              throw StateError('correlation failed');
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AarAttackerCorrelationSection(encounter: s2.encounter),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('aar-attackers-error')), findsOneWidget);
      expect(find.byKey(const Key('aar-actor-row-artem s3')), findsOneWidget);
    });

    testWidgets('T8.8 matchup advisory renders at ≥ 2 correlated', (
      tester,
    ) async {
      const matchup = CombatDamageMatchup(
        targetLabel: 'Pilot',
        layer: 'armor',
        summary: 'kinetic hole',
        entries: [
          CombatDamageMatchupEntry(
            type: 'Kinetic',
            amount: 100,
            percent: 1,
            assessment: DamageMatchupAssessment.resistHole,
            evidence: 'fixture',
            resistPercent: 20,
          ),
        ],
        ehpAgainstPattern: LayeredEhp(
          pattern: DamagePattern.omni,
          shield: 100,
          armor: 100,
          hull: 100,
        ),
        ehpOmni: LayeredEhp(
          pattern: DamagePattern.omni,
          shield: 100,
          armor: 100,
          hull: 100,
        ),
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AarMatchupSection(
                matchup: matchup,
                correlatedAttackerCount: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('aar-matchup-blend-advisory')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AarMatchupSection(
                matchup: matchup,
                correlatedAttackerCount: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('aar-matchup-blend-advisory')), findsNothing);
    });

    testWidgets('T8.9 attacker-fits-unavailable note renders on a loss', (
      tester,
    ) async {
      final s2 = s2Loss();
      await pumpBody(
        tester,
        correlation: correlate(s2),
        incomingBySource: s2.encounter.aggregates.incomingBySource,
      );
      expect(find.byKey(const Key('aar-attackers-fits-note')), findsOneWidget);

      final s1 = s1Kill();
      await pumpBody(
        tester,
        correlation: correlate(s1),
        incomingBySource: s1.encounter.aggregates.incomingBySource,
      );
      expect(find.byKey(const Key('aar-attackers-fits-note')), findsNothing);
    });

    testWidgets('H.10 kill wording for other attackers', (tester) async {
      final s1 = s1Kill();
      final withFleetmate = (
        encounter: s1.encounter,
        detail: s1.detail.copyWith(
          attackers: [
            ...s1.detail.attackers,
            attacker(
              characterId: 9001,
              characterName: 'Fleet Mate',
              shipTypeId: 587,
              damageDone: 50,
            ),
          ],
        ),
      );
      await pumpBody(
        tester,
        correlation: correlate(withFleetmate),
        incomingBySource: s1.encounter.aggregates.incomingBySource,
      );
      expect(
        find.byKey(const Key('aar-attackers-uncorrelated-toggle')),
        findsOneWidget,
      );
      expect(
        textsUnder(tester, const Key('aar-attackers-uncorrelated-toggle')),
        contains('1 other attacker on this kill'),
      );
    });
  });
}
