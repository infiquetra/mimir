import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';

void main() {
  group('ESI killmail models', () {
    test('parses recent killmail refs', () {
      final ref = EsiKillmailRef.fromJson({
        'killmail_id': 123,
        'killmail_hash': 'abc123',
      });

      expect(ref.killmailId, 123);
      expect(ref.killmailHash, 'abc123');
    });

    test('parses detail attackers, victim, and nested items', () {
      final detail = EsiKillmailDetail.fromJson({
        'killmail_id': 123,
        'killmail_time': '2026-05-20T20:01:00Z',
        'solar_system_id': 30000142,
        'victim': {
          'character_id': 9002,
          'corporation_id': 98000001,
          'ship_type_id': 603,
          'damage_taken': 1200,
          'items': [
            {
              'item_type_id': 100,
              'flag': 27,
              'quantity_destroyed': 1,
              'singleton': 0,
              'items': [
                {
                  'item_type_id': 101,
                  'flag': 87,
                  'quantity_destroyed': 80,
                  'singleton': 0,
                },
              ],
            },
          ],
        },
        'attackers': [
          {
            'character_id': 9001,
            'corporation_id': 98000002,
            'ship_type_id': 602,
            'weapon_type_id': 123,
            'damage_done': 1000,
            'final_blow': true,
          },
        ],
      });

      expect(detail.killmailId, 123);
      expect(detail.victim.items.single.typeId, 100);
      expect(detail.victim.items.single.items.single.typeId, 101);
      expect(detail.attackers.single.finalBlow, isTrue);
    });
  });
}
