import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlator.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';

import '../fixtures/attacker_correlation_fixtures.dart';

void main() {
  group('Group C — CombatAttackerCorrelator assign and correlate', () {
    test('T3.1 greedy assignment fixes the highest pair first', () {
      final a = actor('A', damage: 100);
      final b = actor('B', damage: 90);
      final x = participant(key: 'a0', name: 'X', characterId: 1);
      final y = participant(key: 'a1', name: 'Y', characterId: 2);
      final result = CombatAttackerCorrelator.assign(
        actors: [a, b],
        participants: [x, y],
        pairs: [
          PairScore(
            actor: a,
            participant: x,
            score: 0.95,
            signals: const [CorrelationSignal.name],
          ),
          PairScore(
            actor: a,
            participant: y,
            score: 0.60,
            signals: const [CorrelationSignal.name],
          ),
          PairScore(
            actor: b,
            participant: x,
            score: 0.55,
            signals: const [CorrelationSignal.name],
          ),
          PairScore(
            actor: b,
            participant: y,
            score: 0.90,
            signals: const [CorrelationSignal.name],
          ),
        ],
        totalIncomingDamage: 190,
        killmailId: 1,
        selfIsVictim: true,
        now: now,
      );
      expect(result.correlated, hasLength(2));
      expect(
        result.correlated.map(
          (c) => (c.actor.displayName, c.participant.key, c.score),
        ),
        containsAll([('A', 'a0', 0.95), ('B', 'a1', 0.90)]),
      );
    });

    test('T3.2 one-to-one in both directions', () {
      final result = const CombatAttackerCorrelator().correlate(
        encounter: incomingEncounter([
          ('Artem S3', 4200, 'Heavy Missile', 4),
          ('Hurricane', 2600, '425mm AutoCannon II', 8),
        ]),
        detail: detail(
          victim: victim(damageTaken: 6800),
          attackers: [
            attacker(
              characterId: 9001,
              characterName: 'Artem S3',
              shipTypeId: 24702,
              damageDone: 4200,
            ),
            attacker(
              characterId: 9004,
              characterName: 'Pell Ivo',
              shipTypeId: 24702,
              damageDone: 2000,
            ),
          ],
        ),
        typeIndex: typeIndex(),
        now: now,
      );
      expect(result.correlated, hasLength(2));
      final artem = result.correlated.firstWhere(
        (c) => c.actor.displayName == 'Artem S3',
      );
      expect(artem.confidence, AttackerCorrelationConfidence.confirmed);
      expect(artem.score, 0.95);
      final hull = result.correlated.firstWhere(
        (c) => c.actor.displayName == 'Hurricane',
      );
      expect(hull.participant.characterName, 'Pell Ivo');
      expect(hull.confidence, AttackerCorrelationConfidence.probable);
      expect(
        result.correlated.map((c) => c.actor.key).toSet(),
        hasLength(result.correlated.length),
      );
      expect(
        result.correlated.map((c) => c.participant.key).toSet(),
        hasLength(result.correlated.length),
      );
    });

    test('T3.3 ties within 0.10 assign neither', () {
      final result = correlate(s3Fleet());
      expect(result.reasons['actor:sabre'], UncorrelatedReason.ambiguous);
      final sabres = CombatAttackerCorrelator.participants(
        s3Fleet().detail,
        selfCharacterId: 42,
        typeIndex: typeIndex(),
      ).where((p) => p.shipTypeId == 22456);
      for (final sabre in sabres) {
        expect(
          result.reasons['participant:${sabre.key}'],
          UncorrelatedReason.noLogPresence,
        );
      }
    });

    test('T3.4 deterministic across 100 runs including tie-break order', () {
      final first = correlate(s3Fleet());
      final encoded = first.toJson().toString();
      for (var i = 0; i < 100; i++) {
        expect(correlate(s3Fleet()).toJson().toString(), encoded);
      }
      final reversed = s3Fleet();
      final flipped = const CombatAttackerCorrelator().correlate(
        encounter: reversed.encounter,
        detail: reversed.detail.copyWith(
          attackers: reversed.detail.attackers.reversed.toList(),
        ),
        typeIndex: typeIndex(),
        now: now,
      );
      expect(flipped.reasons['actor:sabre'], UncorrelatedReason.ambiguous);
      expect(
        flipped.correlated.map((c) => c.actor.displayName).toSet(),
        first.correlated.map((c) => c.actor.displayName).toSet(),
      );
    });

    test('T3.5 sub-threshold pairs land in belowThreshold', () {
      final result = const CombatAttackerCorrelator().correlate(
        encounter: incomingEncounter([('Zed', 1000, 'Heavy Missile', 4)]),
        detail: detail(
          victim: victim(),
          attackers: [
            attacker(
              characterId: 9001,
              characterName: 'Other',
              weaponTypeId: 2410,
              damageDone: 50,
            ),
          ],
        ),
        typeIndex: typeIndex(),
        now: now,
      );
      expect(result.reasons['actor:zed'], UncorrelatedReason.belowThreshold);
    });

    test('T3.6 damage invariant holds', () {
      for (final scenario in [
        s1Kill(),
        s2Loss(),
        s3Fleet(),
        s4ThirdParty(),
        s5NpcMix(),
      ]) {
        final result = correlate(scenario);
        expect(
          result.correlatedIncomingDamage +
              result.unattributedIncomingDamage +
              result.npcIncomingDamage,
          scenario.encounter.totalDamageReceived,
        );
        expect(result.accountsForAllDamage, isTrue);
      }
    });

    test('T3.7 uncorrelated participants listed with noLogPresence', () {
      final result = correlate(s2Loss());
      expect(
        result.reasons['participant:a3'],
        UncorrelatedReason.noLogPresence,
      );
      expect(
        result.uncorrelatedParticipants.any(
          (p) => p.characterName == 'Pell Ivo',
        ),
        isTrue,
      );
    });

    test('T3.8 NPC damage bucketed separately', () {
      final result = correlate(s5NpcMix());
      expect(result.npcIncomingDamage, 1400);
      expect(result.unattributedIncomingDamage, 0);
      expect(result.reasons['participant:a1'], UncorrelatedReason.npcAttacker);
    });

    test('T3.9 empty attacker list → all actors unattributed, no crash', () {
      final result = const CombatAttackerCorrelator().correlate(
        encounter: incomingEncounter([('Artem S3', 1000, 'Heavy Missile', 4)]),
        detail: detail(victim: victim(), attackers: const []),
        typeIndex: typeIndex(),
        now: now,
      );
      expect(result.correlated, isEmpty);
      expect(
        result.reasons['actor:artem s3'],
        UncorrelatedReason.notOnKillmail,
      );
    });

    test(
      'T3.10 empty log actors → all participants uncorrelated, no crash',
      () {
        final parsed = CombatLogParser.parseLines([
          'Listener: Pilot',
          '[ 2026.05.20 20:00:00 ] (combat) 100 to Enemy - Railgun - Hits',
        ]).single.copyWith(characterId: 42);
        final result = const CombatAttackerCorrelator().correlate(
          encounter: parsed,
          detail: s2Loss().detail,
          typeIndex: typeIndex(),
          now: now,
        );
        expect(result.totalIncomingDamage, 0);
        for (final participant in result.uncorrelatedPlayerParticipants) {
          expect(
            result.reasons['participant:${participant.key}'],
            UncorrelatedReason.noLogPresence,
          );
        }
      },
    );

    test('C.11 notOnKillmail vs belowThreshold', () {
      final thirdParty = correlate(s4ThirdParty());
      expect(
        thirdParty.reasons['actor:kite mondeo'],
        UncorrelatedReason.notOnKillmail,
      );
      final below = const CombatAttackerCorrelator().correlate(
        encounter: incomingEncounter([('Zed', 1000, 'Heavy Missile', 4)]),
        detail: detail(
          victim: victim(),
          attackers: [
            attacker(
              characterId: 9001,
              characterName: 'Other',
              weaponTypeId: 2410,
              damageDone: 50,
            ),
          ],
        ),
        typeIndex: typeIndex(),
        now: now,
      );
      expect(below.reasons['actor:zed'], UncorrelatedReason.belowThreshold);
    });

    test('C.12 the user is excluded from participants', () {
      final people = CombatAttackerCorrelator.participants(
        s1Kill().detail,
        selfCharacterId: 42,
        typeIndex: typeIndex(),
      );
      expect(people, hasLength(1));
      expect(people.single.isVictim, isTrue);
      expect(people.any((p) => p.characterId == 42), isFalse);
    });

    test('C.13 correlated list sorted by actor damage desc', () {
      expect(
        correlate(s2Loss()).correlated.map((c) => c.actor.displayName).toList(),
        ['Artem S3', 'Kite Mondeo', 'Sabre'],
      );
    });

    test('C.14 unnamed damage is unattributed with reason unnamed', () {
      final result = const CombatAttackerCorrelator().correlate(
        encounter: incomingEncounter([('Unknown', 150, 'Heavy Missile', 4)]),
        detail: s4ThirdParty().detail,
        typeIndex: typeIndex(),
        now: now,
      );
      expect(result.reasons['actor:unknown'], UncorrelatedReason.unnamed);
      expect(result.unattributedIncomingDamage, 150);
    });
  });
}
