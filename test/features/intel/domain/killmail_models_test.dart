import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/intel/domain/killmail_models.dart';

void main() {
  group('ZKillmail Models', () {
    test('parses from JSON correctly', () {
      final json = {
        'killmail': {
          'killmail_id': 12345,
          'killmail_time': '2023-01-01T12:00:00Z',
          'solar_system_id': 30000142,
          'victim': {
            'character_id': 999,
            'ship_type_id': 587, // Rifter
            'damage_taken': 1000.0,
          },
          'attackers': [
            {
              'character_id': 888,
              'damage_done': 1000.0,
              'final_blow': true,
            }
          ]
        },
        'zkb': {
          'locationID': 30000142,
          'hash': 'abcdef123456',
          'fittedValue': 500000.0,
          'droppedValue': 100000.0,
          'destroyedValue': 400000.0,
          'totalValue': 600000.0,
          'points': 1,
          'npc': false,
          'solo': true,
          'awox': false,
        }
      };

      final killmail = ZKillmail.fromJson(json);

      expect(killmail.killmailId, 12345);
      expect(killmail.solarSystemId, 30000142);
      expect(killmail.totalValue, 600000.0);
      expect(killmail.victim.shipTypeId, 587);
      expect(killmail.attackerCount, 1);
      expect(killmail.isSoloKill, true);
      expect(killmail.finalBlowAttackerId, 888);
    });
  });
}
