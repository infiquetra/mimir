import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_actor_classifier.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlator.dart';

import '../fixtures/attacker_correlation_fixtures.dart';

void main() {
  group('Group A — CombatActorClassifier', () {
    List<CombatLogActor> classify(
      ParsedHits hits, {
      List<CombatKillmailParticipant> participants = const [],
    }) {
      return CombatActorClassifier.classify(
        encounter: incomingEncounter(hits),
        participants: participants,
        typeIndex: typeIndex(),
      );
    }

    test('T1.1 name matching a resolved attacker classifies player', () {
      final actors = classify(
        [('Artem S3', 1000, 'Heavy Missile', 4)],
        participants: [participant(name: 'Artem S3')],
      );
      expect(actors, hasLength(1));
      expect(actors.single.actorClass, CombatActorClass.player);
      expect(actors.single.resolvedTypeId, isNull);
    });

    test('T1.2 name resolving to a category 11 type classifies npc', () {
      final actors = classify([
        ('Serpentis Watchman', 1400, 'Light Missile', 4),
      ]);
      expect(actors.single.actorClass, CombatActorClass.npc);
      expect(actors.single.resolvedTypeId, 30001);
    });

    test('T1.3 name resolving to a category 6 type classifies shipType', () {
      final actors = classify([('Sabre', 1100, '425mm AutoCannon II', 4)]);
      expect(actors.single.actorClass, CombatActorClass.shipType);
      expect(actors.single.resolvedTypeId, 22456);
    });

    test(
      'T1.4 unresolvable name with no attacker match defaults to player',
      () {
        final actors = classify([('Kite Mondeo', 3100, 'Light Missile', 4)]);
        expect(actors.single.actorClass, CombatActorClass.player);
        expect(actors.single.resolvedTypeId, isNull);
      },
    );

    test(
      'T1.5 name matching both a type and an attacker classifies ambiguous',
      () {
        final actors = classify(
          [('Sabre', 1100, '425mm AutoCannon II', 4)],
          participants: [
            participant(name: 'Sabre', shipTypeId: 22456, characterId: 9003),
          ],
        );
        expect(actors.single.actorClass, CombatActorClass.ambiguous);
        expect(actors.single.isScorable, isTrue);
      },
    );

    test('T1.6 classification is exact normalised match, not substring', () {
      expect(
        classify([
          ('Sabre', 100, '425mm AutoCannon II', 4),
        ]).single.resolvedTypeId,
        22456,
      );
      expect(
        classify([
          ('sabre  ', 100, '425mm AutoCannon II', 4),
        ]).single.resolvedTypeId,
        22456,
      );
      final fleet = classify([
        ('Sabre Fleet', 100, '425mm AutoCannon II', 4),
      ]).single;
      expect(fleet.actorClass, CombatActorClass.player);
      expect(fleet.resolvedTypeId, isNull);
    });

    test(
      'T1.7 empty and Unknown names classify unnamed and keep their damage',
      () {
        final actors = classify([('Unknown', 150, 'Heavy Missile', 4)]);
        expect(actors, hasLength(1));
        expect(actors.single.actorClass, CombatActorClass.unnamed);
        expect(actors.single.damageDealt, 150);
      },
    );

    test('A.8 actor carries distinct sorted weapons and first/last seen', () {
      final actors = classify([
        ('Artem S3', 100, 'Heavy Missile', 4),
        ('Artem S3', 100, 'Heavy Missile', 8),
        ('Artem S3', 100, '425mm AutoCannon II', 12),
      ]);
      expect(actors, hasLength(1));
      expect(actors.single.weaponNames, [
        '425mm AutoCannon II',
        'Heavy Missile',
      ]);
      expect(actors.single.firstSeen!.second, 4);
      expect(actors.single.lastSeen!.second, 12);
    });

    test('A.9 actors are sorted by damage desc then name', () {
      List<String> names() => classify([
        ('Zulu', 100, 'Heavy Missile', 4),
        ('Mike', 300, 'Heavy Missile', 8),
        ('Alpha', 300, 'Heavy Missile', 12),
      ]).map((a) => a.displayName).toList();
      final first = names();
      expect(first, ['Alpha', 'Mike', 'Zulu']);
      for (var i = 0; i < 100; i++) {
        expect(names(), first);
      }
    });

    test('A.10 every actor gets exactly one class', () {
      final scenario = s5NpcMix();
      final actors = CombatActorClassifier.classify(
        encounter: scenario.encounter,
        participants: CombatAttackerCorrelator.participants(
          scenario.detail,
          selfCharacterId: scenario.encounter.characterId,
          typeIndex: typeIndex(),
        ),
        typeIndex: typeIndex(),
      );
      final keys = scenario.encounter.aggregates.incomingBySource.keys
          .map(normalizeCombatName)
          .toSet();
      expect(actors.map((a) => a.key).toSet(), keys);
      expect(actors.length, keys.length);
      expect(actors.every((a) => a.actorClass != null), isTrue);
    });
  });
}

typedef ParsedHits =
    List<(String actor, int amount, String weapon, int second)>;
