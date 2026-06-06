import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_killmail_fit_mapper.dart';
import 'package:mimir/features/fitting/domain/models.dart';

void main() {
  group('CombatKillmailFitMapper', () {
    test('maps killmail item flags into fitting slot groups', () {
      final detail = EsiKillmailDetail(
        killmailId: 100,
        killmailTime: DateTime.utc(2026, 5, 20),
        solarSystemId: 30000142,
        victim: EsiKillmailVictim(
          characterId: 9002,
          corporationId: 98000001,
          allianceId: null,
          shipTypeId: 603,
          damageTaken: 1200,
          items: const [
            EsiKillmailItem(
              typeId: 100,
              flag: 27,
              quantityDestroyed: 1,
              quantityDropped: 0,
              singleton: 0,
              items: [
                EsiKillmailItem(
                  typeId: 101,
                  flag: 87,
                  quantityDestroyed: 80,
                  quantityDropped: 0,
                  singleton: 0,
                  items: [],
                ),
              ],
            ),
            EsiKillmailItem(
              typeId: 200,
              flag: 20,
              quantityDestroyed: 1,
              quantityDropped: 0,
              singleton: 0,
              items: [],
            ),
            EsiKillmailItem(
              typeId: 300,
              flag: 11,
              quantityDestroyed: 1,
              quantityDropped: 0,
              singleton: 0,
              items: [],
            ),
            EsiKillmailItem(
              typeId: 400,
              flag: 92,
              quantityDestroyed: 1,
              quantityDropped: 0,
              singleton: 0,
              items: [],
            ),
            EsiKillmailItem(
              typeId: 500,
              flag: 125,
              quantityDestroyed: 1,
              quantityDropped: 0,
              singleton: 0,
              items: [],
            ),
            EsiKillmailItem(
              typeId: 600,
              flag: 87,
              quantityDestroyed: 2,
              quantityDropped: 3,
              singleton: 0,
              items: [],
            ),
            EsiKillmailItem(
              typeId: 700,
              flag: 5,
              quantityDestroyed: 4,
              quantityDropped: 6,
              singleton: 0,
              items: [],
            ),
          ],
        ),
        attackers: const [],
      );

      final fitting = CombatKillmailFitMapper.mapVictimFit(detail);

      expect(fitting.shipTypeId, 603);
      expect(fitting.highSlots.single.slotType, SlotType.high);
      expect(fitting.highSlots.single.slotIndex, 0);
      expect(fitting.highSlots.single.chargeTypeId, 101);
      expect(fitting.medSlots.single.slotIndex, 1);
      expect(fitting.lowSlots.single.slotIndex, 0);
      expect(fitting.rigSlots.single.slotIndex, 0);
      expect(fitting.subsystems.single.slotIndex, 0);
      expect(fitting.drones.single.quantity, 5);
      expect(fitting.cargo.single.quantity, 10);
    });
  });
}
