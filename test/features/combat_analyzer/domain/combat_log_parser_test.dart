import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';

void main() {
  group('CombatLogParser', () {
    test('segments encounters based on 45s idle gap', () {
      final lines = [
        'Listener: TestPlayer',
        '[ 2026.05.20 20:00:00 ] (combat) 100 to Enemy - Weapon - Hits',
        '[ 2026.05.20 20:00:10 ] (combat) 50 from Enemy - Weapon - Hits',
        // Next line is 50 seconds later, should segment
        '[ 2026.05.20 20:01:00 ] (combat) 200 to AnotherEnemy - Weapon - Hits',
        '[ 2026.05.20 20:01:05 ] (combat) 200 to AnotherEnemy - Weapon - Hits',
      ];

      final encounters = CombatLogParser.parseLines(lines);

      expect(encounters.length, 2);

      // First encounter
      expect(encounters[0].characterName, 'TestPlayer');
      expect(encounters[0].totalDamageDealt, 100);
      expect(encounters[0].totalDamageReceived, 50);
      expect(encounters[0].events, hasLength(2));
      expect(
        encounters[0].startTime.toIso8601String(),
        '2026-05-20T20:00:00.000Z',
      );
      expect(
        encounters[0].endTime.toIso8601String(),
        '2026-05-20T20:00:10.000Z',
      );
      expect(encounters[0].aggregates.damageByTarget['Enemy'], 100);
      expect(encounters[0].aggregates.incomingBySource['Enemy'], 50);

      // Second encounter
      expect(encounters[1].characterName, 'TestPlayer');
      expect(encounters[1].totalDamageDealt, 400);
      expect(encounters[1].totalDamageReceived, 0);
      expect(encounters[1].events, hasLength(2));
      expect(encounters[1].aggregates.damageByTarget['AnotherEnemy'], 400);
      expect(encounters[1].outcome, CombatOutcome.likelyVictory);
    });

    test('parses real EVE HTML-colored combat damage lines', () {
      final lines = [
        '  Listener: Metorian Gaterau',
        '[ 2025.12.13 20:54:13 ] (combat) <color=0xff00ffff><b>38</b> <color=0x77ffffff><font size=10>to</font> <b><color=0xffffffff>Serpentis Watchman</b><font size=10><color=0x77ffffff> - Integrated Acolyte - Hits',
        '[ 2025.12.13 20:54:16 ] (combat) <color=0xffcc0000><b>47</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>Serpentis Watchman</b><font size=10><color=0x77ffffff> - Light Missile - Hits',
      ];

      final encounters = CombatLogParser.parseLines(lines);

      expect(encounters, hasLength(1));
      expect(encounters.single.characterName, 'Metorian Gaterau');
      expect(encounters.single.totalDamageDealt, 38);
      expect(encounters.single.totalDamageReceived, 47);
      expect(encounters.single.events.first.weaponName, 'Integrated Acolyte');
      expect(encounters.single.events.last.weaponName, 'Light Missile');
      expect(encounters.single.outcome, CombatOutcome.likelyDefeat);
    });

    test('ignores non-combat gamelog entries', () {
      final lines = [
        'Listener: Metorian Gaterau',
        '[ 2026.05.20 20:00:00 ] redeeming and injecting 50000 Skill Points',
      ];

      final encounters = CombatLogParser.parseLines(lines);

      expect(encounters, isEmpty);
    });

    test('ignores combat-tagged entries without damage', () {
      final lines = [
        'Listener: Metorian Gaterau',
        '[ 2026.05.20 20:00:00 ] (combat) Your railgun misses Serpentis Watchman completely',
      ];

      final encounters = CombatLogParser.parseLines(lines);

      expect(encounters, isEmpty);
    });

    test('keeps miss events inside damage encounters', () {
      final lines = [
        'Listener: Metorian Gaterau',
        '[ 2026.05.20 20:00:00 ] (combat) Your Light Neutron Blaster II misses State Protector Merlin completely',
        '[ 2026.05.20 20:00:01 ] (combat) 143 to State Protector Merlin - Hobgoblin II - Hits',
      ];

      final encounters = CombatLogParser.parseLines(lines);

      expect(encounters, hasLength(1));
      expect(encounters.single.aggregates.missCount, 1);
      expect(encounters.single.events.first.kind, CombatEventKind.miss);
      expect(
        encounters.single.events.first.weaponName,
        'Light Neutron Blaster II',
      );
    });

    test('computes outgoing application metrics from combat events', () {
      final lines = [
        'Listener: Metorian Gaterau',
        '[ 2026.05.20 20:00:00 ] (combat) Your Light Neutron Blaster II misses State Protector Merlin completely',
        '[ 2026.05.20 20:00:01 ] (combat) 100 to State Protector Merlin - Hobgoblin II - Grazes',
        '[ 2026.05.20 20:00:02 ] (combat) 200 to State Protector Merlin - Hobgoblin II - Hits',
        '[ 2026.05.20 20:00:03 ] (combat) 300 to State Protector Merlin - Hobgoblin II - Penetrates',
        '[ 2026.05.20 20:00:04 ] (combat) 50 from State Protector Merlin - Rocket - Hits',
      ];

      final encounter = CombatLogParser.parseLines(lines).single;
      final aggregates = encounter.aggregates;

      expect(aggregates.outgoingShotCount, 4);
      expect(aggregates.outgoingHitCount, 3);
      expect(aggregates.missCount, 1);
      expect(aggregates.outgoingHitRate, closeTo(0.75, 0.001));
      expect(aggregates.outgoingMissRate, closeTo(0.25, 0.001));
      expect(aggregates.peakOutgoingHit, 300);
      expect(aggregates.averageOutgoingHit, closeTo(200, 0.001));
      expect(aggregates.outgoingHitQualityCounts['Grazes'], 1);
      expect(aggregates.outgoingHitQualityCounts['Penetrates'], 1);
      expect(aggregates.incomingHitQualityCounts['Hits'], 1);
    });
  });
}
