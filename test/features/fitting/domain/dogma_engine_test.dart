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

    test(
      'calculateStats computes base EHP and CPU/PG properly without modules',
      () async {
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
      },
    );

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
          FittedModule(
            typeId: 2048,
            typeName: 'Damage Control II',
            state: ModuleState.online,
            slotType: SlotType.low,
            slotIndex: 0,
          ),
        ],
        rigSlots: [],
      );

      final stats = await engine.calculateStats(fitting, ship, {
        '2048': damageControl,
      }, []);

      expect(stats.cpuUsed, 30.0);
      expect(stats.powerUsed, 1.0);
    });

    test('character skills modify ship attributes postMul', () async {
      final stats = await engine.calculateStats(
        _emptyFitting(),
        _rifter(),
        {},
        [
          const CharacterSkill(skillId: 3418, level: 5), // CPU Management +25%
          const CharacterSkill(skillId: 3455, level: 4), // Navigation +20%
        ],
      );

      expect(stats.cpuMax, closeTo(125 * 1.25, 0.001));
      expect(stats.maxVelocity, closeTo(300 * 1.20, 0.001));
    });

    test('an untrained character sees unmodified base attributes', () async {
      final stats = await engine.calculateStats(
        _emptyFitting(),
        _rifter(),
        {},
        [],
      );

      expect(stats.cpuMax, 125.0);
      expect(stats.maxVelocity, 300.0);
    });

    test('propulsion modules apply speedFactor to max velocity', () async {
      const afterburner = ModuleType(
        typeId: 449,
        name: 'Afterburner I',
        groupId: 46,
        groupName: 'Propulsion',
        slotType: SlotType.med,
        cpu: 10,
        powergrid: 20,
        baseAttributes: {DogmaAttributes.speedFactor: 0.5},
      );
      final fitting = Fitting(
        id: 'ab',
        name: 'Rifter with AB',
        shipTypeId: 587,
        shipName: 'Rifter',
        medSlots: [
          FittedModule(
            typeId: 449,
            typeName: 'Afterburner I',
            state: ModuleState.online,
            slotType: SlotType.med,
            slotIndex: 0,
          ),
        ],
      );

      final stats = await engine.calculateStats(fitting, _rifter(), {
        '449': afterburner,
      }, []);

      expect(stats.maxVelocity, closeTo(300 * 1.5, 0.001));
      expect(stats.cpuUsed, 10.0);
    });

    test('offline modules contribute nothing', () async {
      const afterburner = ModuleType(
        typeId: 449,
        name: 'Afterburner I',
        groupId: 46,
        groupName: 'Propulsion',
        slotType: SlotType.med,
        cpu: 10,
        powergrid: 20,
        baseAttributes: {DogmaAttributes.speedFactor: 0.5},
      );
      final fitting = Fitting(
        id: 'ab-off',
        name: 'Rifter with offline AB',
        shipTypeId: 587,
        shipName: 'Rifter',
        medSlots: [
          FittedModule(
            typeId: 449,
            typeName: 'Afterburner I',
            state: ModuleState.offline,
            slotType: SlotType.med,
            slotIndex: 0,
          ),
        ],
      );

      final stats = await engine.calculateStats(fitting, _rifter(), {
        '449': afterburner,
      }, []);

      expect(stats.maxVelocity, 300.0);
      expect(stats.cpuUsed, 0.0);
    });

    test('shield management raises shield HP and total EHP', () async {
      final untrained = await engine.calculateStats(
        _emptyFitting(),
        _rifter(),
        {},
        [],
      );
      final trained = await engine.calculateStats(
        _emptyFitting(),
        _rifter(),
        {},
        [const CharacterSkill(skillId: 3425, level: 5)], // Shield Management
      );

      expect(trained.defenses.shieldHp, closeTo(400 * 1.25, 0.001));
      expect(
        trained.defenses.totalEhp,
        greaterThan(untrained.defenses.totalEhp),
      );
    });
  });
}

ShipType _rifter() => ShipType(
  typeId: 587,
  name: 'Rifter',
  description: 'A Minmatar frigate',
  groupId: 25,
  groupName: 'Frigate',
  highSlots: 4,
  medSlots: 3,
  lowSlots: 3,
  rigSlots: 3,
  baseAttributes: {
    DogmaAttributes.cpuOutput: 125.0,
    DogmaAttributes.powerOutput: 37.0,
    DogmaAttributes.maxVelocity: 300.0,
    DogmaAttributes.shieldCapacity: 400.0,
    DogmaAttributes.armorHp: 400.0,
    DogmaAttributes.hullHp: 350.0,
    DogmaAttributes.shieldEmResist: 1.0,
    DogmaAttributes.shieldThermalResist: 1.0,
    DogmaAttributes.shieldKineticResist: 1.0,
    DogmaAttributes.shieldExplosiveResist: 1.0,
    DogmaAttributes.armorEmResist: 1.0,
    DogmaAttributes.armorThermalResist: 1.0,
    DogmaAttributes.armorKineticResist: 1.0,
    DogmaAttributes.armorExplosiveResist: 1.0,
    DogmaAttributes.hullEmResist: 1.0,
    DogmaAttributes.hullThermalResist: 1.0,
    DogmaAttributes.hullKineticResist: 1.0,
    DogmaAttributes.hullExplosiveResist: 1.0,
  },
);

Fitting _emptyFitting() => Fitting(
  id: 'empty',
  name: 'Empty Rifter',
  shipTypeId: 587,
  shipName: 'Rifter',
);
