import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlator.dart';

import '../fixtures/attacker_correlation_fixtures.dart';

void main() {
  group('Group B — CombatAttackerCorrelator.score', () {
    PairScore scorePair({
      required CombatLogActor actor,
      required CombatKillmailParticipant participant,
      CorrelationContext? ctx,
    }) {
      return CombatAttackerCorrelator.score(
        actor: actor,
        participant: participant,
        context: ctx ?? context(),
        typeIndex: typeIndex(),
      );
    }

    test('T2.1 name alone reaches confirmed', () {
      final pair = scorePair(
        actor: actor('Artem S3'),
        participant: participant(name: 'Artem S3', damageDone: null),
        ctx: context(playerActorCount: 2, playerParticipantCount: 2),
      );
      expect(pair.score, 0.75);
      expect(pair.band, AttackerCorrelationConfidence.confirmed);
      expect(pair.signals, [CorrelationSignal.name]);
    });

    test('T2.2 damage alone does not correlate', () {
      final pair = scorePair(
        actor: actor('Zed', damage: 1000),
        participant: participant(name: 'Other', damageDone: 1000),
      );
      expect(pair.score, 0.20);
      expect(pair.band, isNull);
    });

    test('T2.3 ship + damage reaches probable, not confirmed', () {
      final pair = scorePair(
        actor: actor(
          'Sabre',
          cls: CombatActorClass.shipType,
          typeId: 22456,
          damage: 1100,
        ),
        participant: participant(
          name: 'Dax Rho',
          shipTypeId: 22456,
          damageDone: 1250,
        ),
      );
      expect(pair.score, 0.50);
      expect(pair.band, AttackerCorrelationConfidence.probable);
      expect(pair.cappedBand, AttackerCorrelationConfidence.probable);
    });

    test('T2.4 damage awards full at 0.60, half at 0.35, none at 0.20', () {
      expect(
        scorePair(
          actor: actor('Zed', damage: 600),
          participant: participant(name: 'Other', damageDone: 1000),
        ).score,
        0.20,
      );
      expect(
        scorePair(
          actor: actor('Zed', damage: 350),
          participant: participant(name: 'Other', damageDone: 1000),
        ).score,
        0.10,
      );
      expect(
        scorePair(
          actor: actor('Zed', damage: 200),
          participant: participant(name: 'Other', damageDone: 1000),
        ).score,
        0,
      );
    });

    test('T2.5 damage mismatch never subtracts', () {
      final pair = scorePair(
        actor: actor('Artem S3', damage: 100),
        participant: participant(name: 'Artem S3', damageDone: 10000),
      );
      expect(pair.score, 0.75);
      expect(pair.signals, [CorrelationSignal.name]);
    });

    test(
      'T2.6 timing fires only for final-blow participant, last incoming actor, self victim',
      () {
        final artem = actor('Artem S3');
        final kite = participant(name: 'Kite Mondeo', finalBlow: true);
        expect(
          scorePair(
            actor: artem,
            participant: kite,
            ctx: context(selfIsVictim: true, lastIncomingActor: 'artem s3'),
          ).signals,
          contains(CorrelationSignal.timing),
        );
        expect(
          scorePair(
            actor: artem,
            participant: participant(name: 'Kite Mondeo', finalBlow: false),
            ctx: context(selfIsVictim: true, lastIncomingActor: 'artem s3'),
          ).signals,
          isNot(contains(CorrelationSignal.timing)),
        );
        expect(
          scorePair(
            actor: artem,
            participant: kite,
            ctx: context(selfIsVictim: true, lastIncomingActor: 'kite mondeo'),
          ).signals,
          isNot(contains(CorrelationSignal.timing)),
        );
        expect(
          scorePair(
            actor: artem,
            participant: kite,
            ctx: context(selfIsVictim: false, lastIncomingActor: 'artem s3'),
          ).signals,
          isNot(contains(CorrelationSignal.timing)),
        );
      },
    );

    test('T2.7 sole fires for 1 player participant and 1 player actor', () {
      final pair = scorePair(
        actor: actor('Zed'),
        participant: participant(name: 'Other'),
        ctx: context(playerActorCount: 1, playerParticipantCount: 1),
      );
      expect(pair.signals, contains(CorrelationSignal.sole));
      expect(pair.score, 0.10);
    });

    test(
      'T2.8 sole does not fire for a shipType actor or when counts differ',
      () {
        expect(
          scorePair(
            actor: actor(
              'Sabre',
              cls: CombatActorClass.shipType,
              typeId: 22456,
            ),
            participant: participant(name: 'Dax Rho', shipTypeId: 22456),
            ctx: context(playerActorCount: 1, playerParticipantCount: 1),
          ).signals,
          isNot(contains(CorrelationSignal.sole)),
        );
        expect(
          scorePair(
            actor: actor('Zed'),
            participant: participant(name: 'Other'),
            ctx: context(playerActorCount: 2, playerParticipantCount: 1),
          ).signals,
          isNot(contains(CorrelationSignal.sole)),
        );
      },
    );

    test('T2.9 weapon fires on exact type and on shared group', () {
      final armed = actor('Zed', weapons: const ['Heavy Missile']);
      expect(
        scorePair(
          actor: armed,
          participant: participant(
            name: 'Other',
            damageDone: null,
            weaponTypeId: 2410,
          ),
        ).score,
        0.20,
      );
      expect(
        scorePair(
          actor: armed,
          participant: participant(
            name: 'Other',
            damageDone: null,
            weaponTypeId: 2412,
            weaponGroupId: 385,
          ),
        ).score,
        0.20,
      );
      expect(
        scorePair(
          actor: armed,
          participant: participant(
            name: 'Other',
            damageDone: null,
            weaponTypeId: 2905,
            weaponGroupId: 55,
          ),
        ).score,
        0,
      );
    });

    test('T2.10 weights are named constants with the documented values', () {
      expect(AttackerCorrelationRules.weights[CorrelationSignal.name], 0.75);
      expect(AttackerCorrelationRules.weights[CorrelationSignal.ship], 0.30);
      expect(AttackerCorrelationRules.weights[CorrelationSignal.weapon], 0.20);
      expect(AttackerCorrelationRules.weights[CorrelationSignal.damage], 0.20);
      expect(AttackerCorrelationRules.weights[CorrelationSignal.timing], 0.15);
      expect(AttackerCorrelationRules.weights[CorrelationSignal.sole], 0.10);
      expect(AttackerCorrelationRules.confirmedThreshold, 0.75);
      expect(AttackerCorrelationRules.probableThreshold, 0.50);
      expect(AttackerCorrelationRules.possibleThreshold, 0.30);
      expect(AttackerCorrelationRules.ambiguityMargin, 0.10);
    });

    test('B.11 shipType actor is capped at probable', () {
      final pair = scorePair(
        actor: actor(
          'Sabre',
          cls: CombatActorClass.shipType,
          typeId: 22456,
          damage: 1100,
          weapons: const ['Heavy Missile'],
        ),
        participant: participant(
          name: 'Dax Rho',
          shipTypeId: 22456,
          weaponTypeId: 2410,
          damageDone: 1250,
          finalBlow: true,
        ),
        ctx: context(
          selfIsVictim: true,
          lastIncomingActor: 'sabre',
          playerActorCount: 2,
          playerParticipantCount: 2,
        ),
      );
      expect(pair.score, 0.85);
      expect(pair.band, AttackerCorrelationConfidence.confirmed);
      expect(pair.cappedBand, AttackerCorrelationConfidence.probable);
    });

    test('B.12 victim participant never earns damage', () {
      final pair = scorePair(
        actor: actor('Vex Kalari', damage: 300),
        participant: participant(
          name: 'Other',
          isVictim: true,
          damageDone: null,
        ),
      );
      expect(pair.signals, isNot(contains(CorrelationSignal.damage)));
    });

    test('B.13 score is clamped to 1.0', () {
      final pair = scorePair(
        actor: actor('Artem S3', damage: 1000),
        participant: participant(
          name: 'Artem S3',
          damageDone: 1000,
          finalBlow: true,
        ),
        ctx: context(
          selfIsVictim: true,
          lastIncomingActor: 'artem s3',
          playerActorCount: 1,
          playerParticipantCount: 1,
        ),
      );
      expect(pair.score, 1.0);
    });

    test('B.14 null participant name is no signal, not a mismatch', () {
      final pair = scorePair(
        actor: actor('Artem S3', damage: 1000),
        participant: participant(name: null, damageDone: 1000),
      );
      expect(pair.signals, isNot(contains(CorrelationSignal.name)));
      expect(pair.signals, contains(CorrelationSignal.damage));
    });
  });
}
