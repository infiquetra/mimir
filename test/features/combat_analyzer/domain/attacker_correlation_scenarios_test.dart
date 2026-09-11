import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';

import '../fixtures/attacker_correlation_fixtures.dart';

void main() {
  group('Group D — attacker correlation scenarios', () {
    test('T4.1 S1 solo kill', () {
      final result = correlate(s1Kill());
      expect(result.correlated, hasLength(1));
      final row = result.correlated.single;
      expect(row.actor.displayName, 'Vex Kalari');
      expect(row.confidence, AttackerCorrelationConfidence.confirmed);
      expect(row.score, 0.85);
      expect(row.signals, [CorrelationSignal.name, CorrelationSignal.sole]);
      expect(result.selfIsVictim, isFalse);
      expect(row.participant.isVictim, isTrue);
    });

    test('T4.2 S2 loss with three attackers and a ship-type actor', () {
      final result = correlate(s2Loss());
      final byName = {
        for (final row in result.correlated) row.actor.displayName: row,
      };
      expect(
        byName['Artem S3']!.confidence,
        AttackerCorrelationConfidence.confirmed,
      );
      expect(byName['Artem S3']!.score, 1.0);
      expect(byName['Artem S3']!.signals, [
        CorrelationSignal.name,
        CorrelationSignal.weapon,
        CorrelationSignal.damage,
      ]);
      expect(
        byName['Kite Mondeo']!.confidence,
        AttackerCorrelationConfidence.confirmed,
      );
      expect(byName['Kite Mondeo']!.score, 1.0);
      expect(byName['Kite Mondeo']!.signals, [
        CorrelationSignal.name,
        CorrelationSignal.weapon,
        CorrelationSignal.damage,
        CorrelationSignal.timing,
      ]);
      expect(
        byName['Sabre']!.confidence,
        AttackerCorrelationConfidence.probable,
      );
      expect(byName['Sabre']!.score, 0.70);
      expect(byName['Sabre']!.signals, [
        CorrelationSignal.ship,
        CorrelationSignal.weapon,
        CorrelationSignal.damage,
      ]);
      expect(
        byName['Sabre']!.confidence,
        isNot(AttackerCorrelationConfidence.confirmed),
      );
      expect(
        result.reasons['participant:a3'],
        UncorrelatedReason.noLogPresence,
      );
      expect(result.correlatedIncomingDamage, 8400);
      expect(result.unattributedIncomingDamage, 0);
      expect(result.npcIncomingDamage, 0);
    });

    test('T4.3 S3 fleet', () {
      final result = correlate(s3Fleet());
      expect(result.correlated, hasLength(6));
      expect(
        result.correlated
            .where(
              (c) => c.confidence == AttackerCorrelationConfidence.confirmed,
            )
            .length,
        4,
      );
      expect(
        result.correlated
            .where(
              (c) => c.confidence == AttackerCorrelationConfidence.probable,
            )
            .length,
        2,
      );
      expect(result.reasons['actor:sabre'], UncorrelatedReason.ambiguous);
      expect(result.uncorrelatedParticipants, hasLength(6));
      expect(result.uncorrelatedPlayerParticipants, hasLength(6));
      final sabre = result.unattributedActors.singleWhere(
        (a) => a.displayName == 'Sabre',
      );
      expect(result.unattributedIncomingDamage, sabre.damageDealt);
    });

    test('T4.4 S4 third party absent from the killmail', () {
      final result = correlate(s4ThirdParty());
      expect(
        result.reasons['actor:kite mondeo'],
        UncorrelatedReason.belowThreshold,
      );
      expect(result.unattributedIncomingDamage, 1100);
      expect(result.correlated.single.actor.displayName, 'Artem S3');
      expect(
        result.correlated.single.confidence,
        AttackerCorrelationConfidence.confirmed,
      );
    });

    test('T4.5 S5 NPC and player mixed', () {
      final result = correlate(s5NpcMix());
      expect(
        result.unattributedActors.any(
          (a) =>
              a.displayName == 'Serpentis Watchman' &&
              a.actorClass == CombatActorClass.npc,
        ),
        isTrue,
      );
      expect(
        result.correlated.any(
          (c) => c.actor.displayName == 'Serpentis Watchman',
        ),
        isFalse,
      );
      final artem = result.correlated.single;
      expect(artem.actor.displayName, 'Artem S3');
      expect(artem.confidence, AttackerCorrelationConfidence.confirmed);
      expect(artem.score, 1.0);
      expect(artem.signals, [
        CorrelationSignal.name,
        CorrelationSignal.weapon,
        CorrelationSignal.damage,
        CorrelationSignal.sole,
      ]);
      expect(result.npcIncomingDamage, 1400);
    });

    test('T4.6 S6 no killmail → null', () {
      const enrichment = CombatEnrichment(
        parsedEncounterId: 'enc-1',
        status: CombatEnrichmentStatus.logOnly,
        source: CombatEnrichmentSource.none,
      );
      expect(enrichment.attackerCorrelation, isNull);
      expect(AttackerCorrelation.fromJson(null), isNull);
    });

    test('D.7 JSON round-trip for every scenario', () {
      for (final scenario in [
        s1Kill(),
        s2Loss(),
        s3Fleet(),
        s4ThirdParty(),
        s5NpcMix(),
      ]) {
        final original = correlate(scenario);
        final roundTripped = AttackerCorrelation.fromJson(
          jsonDecode(jsonEncode(original.toJson())),
        );
        expect(roundTripped, isNotNull);
        expect(roundTripped!.toJson(), original.toJson());
      }
    });

    test('D.8 fromJson tolerates unknown enum names and missing keys', () {
      final skipped = AttackerCorrelation.fromJson({
        'killmailId': 1,
        'selfIsVictim': true,
        'rulesVersion': 1,
        'correlated': [
          {
            'actor': {
              'displayName': 'Artem S3',
              'actorClass': 'player',
              'damageDealt': 100,
              'weaponNames': <String>[],
            },
            'participant': {
              'key': 'a0',
              'characterId': 9001,
              'characterName': 'Artem S3',
              'finalBlow': false,
              'isVictim': false,
            },
            'confidence': 'certain',
            'score': 0.9,
            'signals': ['name'],
          },
        ],
        'unattributedActors': <Map<String, dynamic>>[],
        'uncorrelatedParticipants': <Map<String, dynamic>>[],
        'correlatedIncomingDamage': 0,
        'unattributedIncomingDamage': 0,
        'npcIncomingDamage': 0,
        'totalIncomingDamage': 0,
        'correlatedAt': now.toIso8601String(),
      });
      expect(skipped, isNotNull);
      expect(skipped!.correlated, isEmpty);
      expect(skipped.reasons, isEmpty);

      expect(AttackerCorrelation.fromJson({'selfIsVictim': true}), isNull);
    });
  });
}
