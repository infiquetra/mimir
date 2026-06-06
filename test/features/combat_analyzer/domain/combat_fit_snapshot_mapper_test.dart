import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_fit_snapshot_mapper.dart';
import 'package:mimir/features/fitting/domain/models.dart';

void main() {
  group('CombatFitSnapshotMapper', () {
    test('maps current ship assets into fitting slot groups and cargo', () {
      final fitting = CombatFitSnapshotMapper.mapCurrentShipAssets(
        characterId: 9001,
        ship: CharacterShip(
          shipTypeId: 587,
          shipItemId: 123456,
          shipName: 'Manual Rifter',
          shipTypeName: 'Rifter',
        ),
        assets: const [
          AssetItem(
            itemId: 1,
            typeId: 2048,
            quantity: 1,
            locationId: 123456,
            locationFlag: 'LoSlot0',
            isSingleton: true,
          ),
          AssetItem(
            itemId: 2,
            typeId: 5973,
            quantity: 1,
            locationId: 123456,
            locationFlag: 'MedSlot1',
            isSingleton: true,
          ),
          AssetItem(
            itemId: 3,
            typeId: 484,
            quantity: 1,
            locationId: 123456,
            locationFlag: 'HiSlot0',
            isSingleton: true,
          ),
          AssetItem(
            itemId: 4,
            typeId: 12820,
            quantity: 250,
            locationId: 3,
            locationFlag: 'HiSlot0',
            isSingleton: false,
          ),
          AssetItem(
            itemId: 5,
            typeId: 2454,
            quantity: 3,
            locationId: 123456,
            locationFlag: 'DroneBay',
            isSingleton: false,
          ),
          AssetItem(
            itemId: 6,
            typeId: 34,
            quantity: 100,
            locationId: 123456,
            locationFlag: 'Cargo',
            isSingleton: false,
          ),
        ],
      );

      expect(fitting.shipTypeId, 587);
      expect(fitting.lowSlots.single.slotType, SlotType.low);
      expect(fitting.lowSlots.single.slotIndex, 0);
      expect(fitting.medSlots.single.slotIndex, 1);
      expect(fitting.highSlots.single.chargeTypeId, 12820);
      expect(fitting.drones.single.quantity, 3);
      expect(fitting.cargo.single.quantity, 100);
    });
  });
}
