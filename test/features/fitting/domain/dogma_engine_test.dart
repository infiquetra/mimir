import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/fitting/domain/dogma_engine.dart';
import 'package:mimir/features/fitting/domain/dogma_attributes.dart';
import 'package:mimir/features/fitting/domain/models.dart';

void main() {
  group('DogmaEngine', () {
    late DogmaEngine engine;

    setUp(() {
      engine = DogmaEngine();
    });

    test('getStackingPenalty returns correct multiplier', () {
      expect(DogmaEngine.getStackingPenalty(1), equals(1.0));
      expect(DogmaEngine.getStackingPenalty(2), closeTo(0.869, 0.001));
      expect(DogmaEngine.getStackingPenalty(3), closeTo(0.571, 0.001));
      expect(DogmaEngine.getStackingPenalty(4), closeTo(0.283, 0.001));
      expect(DogmaEngine.getStackingPenalty(5), closeTo(0.106, 0.001));
      expect(DogmaEngine.getStackingPenalty(6), closeTo(0.030, 0.001));
    });

    test('calculateStats computes base EHP and CPU/PG properly without modules', () async {
      final ship = ShipType(
        typeId: 587,
        name: 'Rifter',
        description: 'A Minmatar frigate',
        groupId: 25,
        groupName: 'Frigate',
        baseAttributes: {
          DogmaAttributes.cpuOutput: 125.0,
          DogmaAttributes.powerOutput: 37.0,
          DogmaAttributes.shieldCapacity: 350.0,
          DogmaAttributes.armorHp: 400.0,
          DogmaAttributes.hullHp: 350.0,
          DogmaAttributes.shieldEmResist: 1.0,
          DogmaAttributes.shieldThermalResist: 0.8,
          DogmaAttributes.shieldKineticResist: 0.6,
          DogmaAttributes.shieldExplosiveResist: 0.5,
          DogmaAttributes.armorEmResist: 0.5,
          DogmaAttributes.armorThermalResist: 0.65,
          DogmaAttributes.armorKineticResist: 0.75,
          DogmaAttributes.armorExplosiveResist: 0.9,
          DogmaAttributes.hullEmResist: 1.0,
          DogmaAttributes.hullThermalResist: 1.0,
          DogmaAttributes.hullKineticResist: 1.0,
          DogmaAttributes.hullExplosiveResist: 1.0,
        },
        skillRequirements: [],
        highSlots: 4,
        medSlots: 3,
        lowSlots: 3,
        rigSlots: 3,
      );

      final fitting = Fitting(
        id: '1',
        name: 'Empty Rifter',
        shipTypeId: 587,
        shipName: 'Rifter',
        highSlots: [],
        medSlots: [],
        lowSlots: [],
        rigSlots: [],
      );

      final stats = await engine.calculateStats(fitting, ship, {}, []);

      expect(stats.cpuMax, 125.0);
      expect(stats.powerMax, 37.0);
      expect(stats.cpuUsed, 0.0);
      expect(stats.powerUsed, 0.0);
      expect(stats.defenses.shieldHp, 350.0);
      expect(stats.defenses.armorHp, 400.0);
      expect(stats.defenses.hullHp, 350.0);

      // Verify EHP calculations
      // Shield: EM 0%, Th 20%, Kin 40%, Exp 50% => Avg 27.5% resist => 350 / (1 - 0.275) = ~482.7
      expect(stats.defenses.shieldEhp, closeTo(482.75, 0.02));
    });

    test('calculateStats computes CPU/PG properly with modules', () async {
      final ship = ShipType(
        typeId: 587,
        name: 'Rifter',
        description: 'A Minmatar frigate',
        groupId: 25,
        groupName: 'Frigate',
        baseAttributes: {
          DogmaAttributes.cpuOutput: 125.0,
          DogmaAttributes.powerOutput: 37.0,
          DogmaAttributes.upgradeLoad: 400.0,
        },
        skillRequirements: [],
        highSlots: 4,
        medSlots: 3,
        lowSlots: 3,
        rigSlots: 3,
      );

      final damageControl = ModuleType(
        typeId: 2048,
        name: 'Damage Control II',
        groupId: 1306,
        groupName: 'Damage Control',
        slotType: SlotType.low,
        metaLevel: 5,
        techLevel: 2,
        cpu: 30.0,
        powergrid: 1.0,
        calibration: 0,
        baseAttributes: {},
        effects: [],
        skillRequirements: [],
        acceptedChargeGroups: [],
      );

      final fitting = Fitting(
        id: '1',
        name: 'Test Rifter',
        shipTypeId: 587,
        shipName: 'Rifter',
        highSlots: [],
        medSlots: [],
        lowSlots: [
          FittedModule(typeId: 2048, typeName: 'Damage Control II', state: ModuleState.online, slotType: SlotType.low, slotIndex: 0),
        ],
        rigSlots: [],
      );

      final stats = await engine.calculateStats(fitting, ship, {'2048': damageControl}, []);

      expect(stats.cpuUsed, 30.0);
      expect(stats.powerUsed, 1.0);
    });
  });
}
