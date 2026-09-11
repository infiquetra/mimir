import 'dart:convert';
import 'dart:io';

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

    test(
      'propulsion modules do not invent speed without ESI modifiers',
      () async {
        // The afterburner/MWD speed bonus lives in a dogma expression tree that
        // ESI does not publish as modifiers (verified live: effect 6731 returns
        // an empty modifier list), and the module's speedFactor attribute is in
        // percent units (135 on a 1MN AB II). Until expression trees are
        // modelled, the engine reports base+skill velocity rather than a
        // guessed multiplier — a wrong speed would be worse than no speed.
        const afterburner = ModuleType(
          typeId: 449,
          name: 'Afterburner I',
          groupId: 46,
          groupName: 'Propulsion',
          slotType: SlotType.med,
          cpu: 10,
          powergrid: 20,
          baseAttributes: {DogmaAttributes.speedFactor: 135.0},
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

        expect(stats.maxVelocity, 300.0);
        expect(stats.cpuUsed, 10.0);
      },
    );

    test('propulsion modules apply the verified speedFactor bonus', () async {
      // Effect 6731 (moduleBonusAfterburner) carries its bonus in an
      // expression tree ESI does not publish; the engine applies the
      // curated, cross-checked mapping: speedFactor 135 (percent units)
      // postPercent onto max velocity, i.e. x2.35.
      const afterburner = ModuleType(
        typeId: 438,
        name: '1MN Afterburner II',
        groupId: 46,
        groupName: 'Propulsion',
        slotType: SlotType.med,
        cpu: 10,
        powergrid: 20,
        baseAttributes: {DogmaAttributes.speedFactor: 135.0},
        effects: [DogmaEffect(effectId: 6731, name: 'moduleBonusAfterburner')],
      );
      final fitting = Fitting(
        id: 'ab',
        name: 'Rifter with AB II',
        shipTypeId: 587,
        shipName: 'Rifter',
        medSlots: [
          FittedModule(
            typeId: 438,
            typeName: '1MN Afterburner II',
            state: ModuleState.online,
            slotType: SlotType.med,
            slotIndex: 0,
          ),
        ],
      );

      final stats = await engine.calculateStats(fitting, _rifter(), {
        '438': afterburner,
      }, []);

      expect(stats.maxVelocity, closeTo(300 * 2.35, 0.001));
      expect(stats.cpuUsed, 10.0);
    });

    test(
      'propulsion effects without the curated mapping change nothing',
      () async {
        const mystery = ModuleType(
          typeId: 999,
          name: 'Mystery drive',
          groupId: 46,
          groupName: 'Propulsion',
          slotType: SlotType.med,
          baseAttributes: {DogmaAttributes.speedFactor: 500.0},
          effects: [DogmaEffect(effectId: 424242, name: 'unknown')],
        );
        final fitting = Fitting(
          id: 'm',
          name: 'Rifter with mystery',
          shipTypeId: 587,
          shipName: 'Rifter',
          medSlots: [
            FittedModule(
              typeId: 999,
              typeName: 'Mystery drive',
              state: ModuleState.online,
              slotType: SlotType.med,
              slotIndex: 0,
            ),
          ],
        );

        final stats = await engine.calculateStats(fitting, _rifter(), {
          '999': mystery,
        }, []);

        expect(stats.maxVelocity, 300.0);
      },
    );

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

    test('capacitor stability simulates repeating drains', () async {
      final ship = _rifter().copyWith(
        baseAttributes: {
          ..._rifter().baseAttributes,
          DogmaAttributes.capacitorCapacity: 1000.0,
          DogmaAttributes.capacitorRechargeTime: 60000.0,
        },
      );
      const module = ModuleType(
        typeId: 777,
        name: 'Cap hungry module',
        groupId: 1,
        groupName: 'Test',
        slotType: SlotType.med,
        baseAttributes: {
          DogmaAttributes.capacitorNeed: 60.0,
          DogmaAttributes.duration: 5000.0,
        },
      );
      final fitting = Fitting(
        id: 'cap',
        name: 'Rifter with cap drain',
        shipTypeId: 587,
        shipName: 'Rifter',
        medSlots: [
          FittedModule(
            typeId: 777,
            typeName: 'Cap hungry module',
            slotType: SlotType.med,
            slotIndex: 0,
            state: ModuleState.online,
          ),
        ],
      );

      final stats = await engine.calculateStats(fitting, ship, {
        '777': module,
      }, []);

      expect(stats.isCapStable, isTrue);
      expect(stats.capacitorStable, greaterThan(0));
      expect(stats.capacitorStable, lessThanOrEqualTo(100));
    });

    test('without drains the capacitor reports fully stable', () async {
      final ship = _rifter().copyWith(
        baseAttributes: {
          ..._rifter().baseAttributes,
          DogmaAttributes.capacitorCapacity: 1000.0,
          DogmaAttributes.capacitorRechargeTime: 60000.0,
        },
      );

      final stats = await engine.calculateStats(_emptyFitting(), ship, {}, []);

      expect(stats.isCapStable, isTrue);
      expect(stats.capacitorStable, closeTo(100, 0.001));
    });

    test('align time and warp speed follow the pyfa closed forms', () async {
      final ship = _rifter().copyWith(
        baseAttributes: {
          ..._rifter().baseAttributes,
          DogmaAttributes.mass: 1067000.0,
          DogmaAttributes.inertiaModifier: 3.2,
          DogmaAttributes.warpSpeedMultiplier: 5.0,
        },
      );

      final stats = await engine.calculateStats(_emptyFitting(), ship, {}, []);

      // -ln(0.25) * 3.2 * 1067000 / 1e6
      expect(stats.alignTime, closeTo(4.7334, 0.001));
      expect(stats.warpSpeed, 5.0);
    });

    test(
      'drone bandwidth and bay capacity come from ship attributes',
      () async {
        final ship = _rifter().copyWith(
          baseAttributes: {
            ..._rifter().baseAttributes,
            DogmaAttributes.droneBandwidth: 50.0,
            DogmaAttributes.droneCapacity: 40.0,
          },
        );

        final stats = await engine.calculateStats(
          _emptyFitting(),
          ship,
          {},
          [],
        );

        expect(stats.droneBandwidthMax, 50.0);
        expect(stats.droneBayMax, 40.0);
      },
    );
  });

  group('DogmaEngine weapon bonuses', () {
    late DogmaEngine engine;

    setUp(() {
      engine = DogmaEngine();
    });

    // Rifter's real traits as CCP resolves them in the SDE: +10% falloff and
    // -7.5% rate of fire per level of Minmatar Frigate (3329, the ship's
    // required skill), filtered to weapons requiring Small Projectile
    // Turret (3302) — modifierInfo's skillTypeID is the filter, not the
    // scaling skill.
    const falloffBonusEffect = 5779;
    const rofBonusEffect = 7248;
    const missileDamageEffect = 898;
    const minmatarFrigate = 3329;
    const smallProjectileTurret = 3302;
    const missileLauncherOperation = 3319;
    const caldariFrigate = 3328;

    ShipType bonusShip({
      List<DogmaEffect> effects = const [],
      Map<int, double> extraAttributes = const {},
    }) => ShipType(
      typeId: 587,
      name: 'Rifter',
      description: 'A Minmatar frigate',
      groupId: 25,
      groupName: 'Frigate',
      highSlots: 4,
      medSlots: 3,
      lowSlots: 3,
      rigSlots: 3,
      effects: effects,
      baseAttributes: {
        ..._rifter().baseAttributes,
        182: minmatarFrigate.toDouble(),
        ...extraAttributes,
      },
    );

    ModuleType weapon({
      required int typeId,
      required int groupId,
      required Map<int, double> baseAttributes,
    }) => ModuleType(
      typeId: typeId,
      name: 'Test weapon $typeId',
      groupId: groupId,
      groupName: 'Test weapons',
      slotType: SlotType.high,
      baseAttributes: baseAttributes,
      effects: const [],
      skillRequirements: const [],
      acceptedChargeGroups: const [],
    );

    final turretAttrs = {
      DogmaAttributes.turretDamageMultiplier: 2.0,
      DogmaAttributes.rateOfFire: 4000.0,
      DogmaAttributes.optimalRange: 10000.0,
      DogmaAttributes.falloff: 5000.0,
      182: smallProjectileTurret.toDouble(),
    };

    ModuleType kineticAmmo() => weapon(
      typeId: 266,
      groupId: 38,
      baseAttributes: {
        DogmaAttributes.kineticDamage: 100.0,
        182: missileLauncherOperation.toDouble(),
      },
    );

    Fitting armedFitting(List<int> weaponTypeIds) => Fitting(
      id: 'armed',
      name: 'Armed Rifter',
      shipTypeId: 587,
      shipName: 'Rifter',
      highSlots: [
        for (var i = 0; i < weaponTypeIds.length; i++)
          FittedModule(
            typeId: weaponTypeIds[i],
            typeName: 'Test weapon ${weaponTypeIds[i]}',
            slotType: SlotType.high,
            slotIndex: i,
            chargeTypeId: 266,
            chargeName: 'Test ammo',
          ),
      ],
    );

    Map<int, List<EffectModifier>> rifterModifiers({int? falloffGroupId}) => {
      falloffBonusEffect: [
        EffectModifier(
          effectId: falloffBonusEffect,
          func: 'LocationRequiredSkillModifier',
          operator: 6,
          modifiedAttributeId: DogmaAttributes.falloff,
          modifyingAttributeId: 587,
          skillTypeId: smallProjectileTurret,
          groupId: falloffGroupId,
        ),
      ],
      rofBonusEffect: [
        EffectModifier(
          effectId: rofBonusEffect,
          func: 'LocationRequiredSkillModifier',
          operator: 6,
          modifiedAttributeId: DogmaAttributes.rateOfFire,
          modifyingAttributeId: 460,
          skillTypeId: smallProjectileTurret,
        ),
      ],
    };

    test(
      'skill-scaled ship bonuses drive turret DPS, volley and ranges',
      () async {
        final stats = await engine.calculateStats(
          armedFitting([561]),
          bonusShip(
            effects: const [
              DogmaEffect(effectId: falloffBonusEffect, name: 'falloff'),
              DogmaEffect(effectId: rofBonusEffect, name: 'rof'),
            ],
            extraAttributes: {587: 10.0, 460: -7.5},
          ),
          {
            '561': weapon(
              typeId: 561,
              groupId: 53,
              baseAttributes: turretAttrs,
            ),
            '266': kineticAmmo(),
          },
          const [CharacterSkill(skillId: minmatarFrigate, level: 5)],
          effectModifiers: rifterModifiers(),
        );

        // Cycle 4000ms * (1 - 7.5*5/100) = 2500ms; volley 100 * 2 = 200.
        expect(stats.volley, closeTo(200, 0.001));
        expect(stats.dpsGuns, closeTo(80, 0.001));
        expect(stats.dpsTotal, closeTo(80, 0.001));
        expect(stats.dpsMissiles, 0.0);
        expect(stats.optimalRange, closeTo(10000, 0.001));
        expect(stats.falloffRange, closeTo(5000 * 1.5, 0.001));
      },
    );

    test('untrained bonus skill leaves base weapon stats', () async {
      final stats = await engine.calculateStats(
        armedFitting([561]),
        bonusShip(
          effects: const [
            DogmaEffect(effectId: falloffBonusEffect, name: 'falloff'),
            DogmaEffect(effectId: rofBonusEffect, name: 'rof'),
          ],
          extraAttributes: {587: 10.0, 460: -7.5},
        ),
        {
          '561': weapon(typeId: 561, groupId: 53, baseAttributes: turretAttrs),
          '266': kineticAmmo(),
        },
        const [],
        effectModifiers: rifterModifiers(),
      );

      expect(stats.dpsGuns, closeTo(200 / 4, 0.001));
      expect(stats.falloffRange, closeTo(5000, 0.001));
    });

    test('missile damage bonuses apply to loaded charges', () async {
      final stats = await engine.calculateStats(
        armedFitting([1120]),
        bonusShip(
          effects: const [
            DogmaEffect(effectId: missileDamageEffect, name: 'missile dmg'),
          ],
          extraAttributes: {463: 10.0, 182: caldariFrigate.toDouble()},
        ),
        {
          '1120': weapon(
            typeId: 1120,
            groupId: 506,
            baseAttributes: {DogmaAttributes.rateOfFire: 2000.0},
          ),
          '266': kineticAmmo(),
        },
        const [CharacterSkill(skillId: caldariFrigate, level: 4)],
        effectModifiers: {
          missileDamageEffect: [
            EffectModifier(
              effectId: missileDamageEffect,
              func: 'OwnerRequiredSkillModifier',
              operator: 6,
              modifiedAttributeId: DogmaAttributes.kineticDamage,
              modifyingAttributeId: 463,
              domain: 'charID',
              skillTypeId: missileLauncherOperation,
            ),
          ],
        },
      );

      // Charge kinetic 100 * (1 + 10*4/100) = 140 volley; 140 / 2s = 70 dps.
      expect(stats.dpsMissiles, closeTo(70, 0.001));
      expect(stats.dpsGuns, 0.0);
      expect(stats.volley, closeTo(140, 0.001));
      expect(stats.optimalRange, 0.0);
    });

    test('group-restricted bonuses skip weapons of other groups', () async {
      final stats = await engine.calculateStats(
        armedFitting([561, 562]),
        bonusShip(
          effects: const [
            DogmaEffect(effectId: falloffBonusEffect, name: 'falloff'),
          ],
          extraAttributes: {587: 10.0},
        ),
        {
          '561': weapon(typeId: 561, groupId: 53, baseAttributes: turretAttrs),
          '562': weapon(typeId: 562, groupId: 54, baseAttributes: turretAttrs),
          '266': kineticAmmo(),
        },
        const [CharacterSkill(skillId: minmatarFrigate, level: 5)],
        effectModifiers: rifterModifiers(falloffGroupId: 53),
      );

      // Only the group-53 turret gets +50% falloff: volley-weighted
      // (7500*200 + 5000*200) / 400.
      expect(stats.volley, closeTo(400, 0.001));
      expect(stats.falloffRange, closeTo(6250, 0.001));
    });

    test('unloaded weapons contribute no damage', () async {
      final fitting = Fitting(
        id: 'unloaded',
        name: 'Unloaded Rifter',
        shipTypeId: 587,
        shipName: 'Rifter',
        highSlots: [
          FittedModule(
            typeId: 561,
            typeName: 'Test weapon 561',
            slotType: SlotType.high,
            slotIndex: 0,
          ),
        ],
      );
      final stats = await engine.calculateStats(fitting, bonusShip(), {
        '561': weapon(typeId: 561, groupId: 53, baseAttributes: turretAttrs),
      }, const []);

      expect(stats.dpsTotal, 0.0);
      expect(stats.volley, 0.0);
    });
  });

  group('DogmaEngine drones and damage modules', () {
    late DogmaEngine engine;

    setUp(() {
      engine = DogmaEngine();
    });

    const heatSinkEffect = 91;
    const bcsEffect = 763;
    const ddaEffect = 6556;
    const dronesSkill = 3436;

    ShipType droneShip({
      List<DogmaEffect> effects = const [],
      double bandwidth = 25,
    }) => ShipType(
      typeId: 587,
      name: 'Rifter',
      description: 'A Minmatar frigate',
      groupId: 25,
      groupName: 'Frigate',
      effects: effects,
      baseAttributes: {
        ..._rifter().baseAttributes,
        DogmaAttributes.droneBandwidth: bandwidth,
        DogmaAttributes.droneCapacity: 40.0,
      },
    );

    ModuleType drone() => ModuleType(
      typeId: 2488,
      name: 'Warrior II',
      groupId: 100,
      groupName: 'Combat Drone',
      slotType: SlotType.high,
      baseAttributes: {
        DogmaAttributes.explosiveDamage: 10.0,
        DogmaAttributes.turretDamageMultiplier: 2.0,
        DogmaAttributes.rateOfFire: 4000.0,
        DogmaAttributes.bandwidthNeeded: 5.0,
        DogmaAttributes.volume: 5.0,
        184: dronesSkill.toDouble(),
      },
      effects: const [],
      skillRequirements: const [],
      acceptedChargeGroups: const [],
    );

    Fitting droneFitting({
      int quantity = 5,
      int inSpace = 0,
      bool amp = false,
    }) => Fitting(
      id: 'drones',
      name: 'Drone Rifter',
      shipTypeId: 587,
      shipName: 'Rifter',
      lowSlots: amp
          ? [
              FittedModule(
                typeId: 4405,
                typeName: 'Drone Damage Amplifier II',
                slotType: SlotType.low,
                slotIndex: 0,
              ),
            ]
          : const [],
      drones: [
        DroneGroup(
          typeId: 2488,
          typeName: 'Warrior II',
          quantity: quantity,
          inSpace: inSpace,
        ),
      ],
    );

    ShipType plainShip() => ShipType(
      typeId: 587,
      name: 'Rifter',
      description: 'A Minmatar frigate',
      groupId: 25,
      groupName: 'Frigate',
      baseAttributes: _rifter().baseAttributes,
    );

    ModuleType item({
      required int typeId,
      required int groupId,
      required Map<int, double> baseAttributes,
      List<DogmaEffect> effects = const [],
    }) => ModuleType(
      typeId: typeId,
      name: 'Test item $typeId',
      groupId: groupId,
      groupName: 'Test items',
      slotType: SlotType.high,
      baseAttributes: baseAttributes,
      effects: effects,
      skillRequirements: const [],
      acceptedChargeGroups: const [],
    );

    test('drone DPS follows damage components, modifier and cycle', () async {
      final stats = await engine.calculateStats(
        droneFitting(quantity: 5),
        droneShip(),
        {'2488': drone()},
        const [],
      );

      // volley 10 * 2 = 20 per drone, 4s cycle => 5 dps each, 5 active.
      expect(stats.dpsDrones, closeTo(25, 0.001));
      expect(stats.dpsTotal, closeTo(25, 0.001));
      expect(stats.droneBandwidthUsed, 25.0);
      expect(stats.droneBayUsed, 25.0);
    });

    test('drone bandwidth caps active drones', () async {
      final stats = await engine.calculateStats(
        droneFitting(quantity: 5),
        droneShip(bandwidth: 12),
        {'2488': drone()},
        const [],
      );

      expect(stats.droneBandwidthUsed, 10.0);
      expect(stats.dpsDrones, closeTo(10, 0.001));
    });

    test('drones recorded in space limit the active count', () async {
      final stats = await engine.calculateStats(
        droneFitting(quantity: 5, inSpace: 2),
        droneShip(),
        {'2488': drone()},
        const [],
      );

      expect(stats.droneBandwidthUsed, 10.0);
      expect(stats.dpsDrones, closeTo(10, 0.001));
      expect(stats.droneBayUsed, 25.0);
    });

    test(
      'damage amps apply raw to drones that require the linked skill',
      () async {
        final stats = await engine.calculateStats(
          droneFitting(quantity: 1, amp: true),
          droneShip(),
          {
            '2488': drone(),
            '4405': ModuleType(
              typeId: 4405,
              name: 'Drone Damage Amplifier II',
              groupId: 645,
              groupName: 'Drone Damage Modules',
              slotType: SlotType.low,
              baseAttributes: {1255: 20.5},
              effects: const [DogmaEffect(effectId: ddaEffect, name: 'dda')],
              skillRequirements: const [],
              acceptedChargeGroups: const [],
            ),
          },
          const [], // untrained: amps filter by the drone's own skill,
          // they do not scale with a character skill level.
          effectModifiers: {
            ddaEffect: [
              EffectModifier(
                effectId: ddaEffect,
                func: 'OwnerRequiredSkillModifier',
                operator: 6,
                modifiedAttributeId: DogmaAttributes.turretDamageMultiplier,
                modifyingAttributeId: 1255,
                domain: 'charID',
                skillTypeId: dronesSkill,
              ),
            ],
          },
        );

        // volley 10 * (2 * 1.205) = 24.1, 4s cycle.
        expect(stats.dpsDrones, closeTo(24.1 / 4, 0.001));
      },
    );

    test('heat sinks multiply turret damage with operator 4', () async {
      final stats = await engine.calculateStats(
        Fitting(
          id: 'hs',
          name: 'Heat Sink Rifter',
          shipTypeId: 587,
          shipName: 'Rifter',
          highSlots: [
            FittedModule(
              typeId: 561,
              typeName: 'Test weapon 561',
              slotType: SlotType.high,
              slotIndex: 0,
              chargeTypeId: 266,
              chargeName: 'Test ammo',
            ),
          ],
          lowSlots: [
            FittedModule(
              typeId: 2048,
              typeName: 'Heat Sink II',
              slotType: SlotType.low,
              slotIndex: 0,
            ),
          ],
        ),
        plainShip(),
        {
          '561': item(
            typeId: 561,
            groupId: 53,
            baseAttributes: {
              DogmaAttributes.turretDamageMultiplier: 2.0,
              DogmaAttributes.rateOfFire: 4000.0,
            },
          ),
          '266': item(
            typeId: 266,
            groupId: 38,
            baseAttributes: {DogmaAttributes.kineticDamage: 100.0},
          ),
          '2048': ModuleType(
            typeId: 2048,
            name: 'Heat Sink II',
            groupId: 53,
            groupName: 'Heat Sink',
            slotType: SlotType.low,
            baseAttributes: {DogmaAttributes.turretDamageMultiplier: 1.1},
            effects: const [DogmaEffect(effectId: heatSinkEffect, name: 'hs')],
            skillRequirements: const [],
            acceptedChargeGroups: const [],
          ),
        },
        const [],
        effectModifiers: {
          heatSinkEffect: [
            EffectModifier(
              effectId: heatSinkEffect,
              func: 'LocationGroupModifier',
              operator: 4,
              modifiedAttributeId: DogmaAttributes.turretDamageMultiplier,
              modifyingAttributeId: DogmaAttributes.turretDamageMultiplier,
              groupId: 53,
            ),
          ],
        },
      );

      // 2.0 * 1.1 = 2.2 damage modifier => volley 220, 4s cycle.
      expect(stats.volley, closeTo(220, 0.001));
      expect(stats.dpsGuns, closeTo(55, 0.001));
    });

    test(
      'ballistic control systems multiply missile damage components',
      () async {
        final stats = await engine.calculateStats(
          Fitting(
            id: 'bcs',
            name: 'BCS Rifter',
            shipTypeId: 587,
            shipName: 'Rifter',
            highSlots: [
              FittedModule(
                typeId: 1120,
                typeName: 'Test launcher',
                slotType: SlotType.high,
                slotIndex: 0,
                chargeTypeId: 266,
                chargeName: 'Test missile',
              ),
            ],
            lowSlots: [
              FittedModule(
                typeId: 22291,
                typeName: 'Ballistic Control System II',
                slotType: SlotType.low,
                slotIndex: 0,
              ),
            ],
          ),
          plainShip(),
          {
            '1120': item(
              typeId: 1120,
              groupId: 506,
              baseAttributes: {DogmaAttributes.rateOfFire: 2000.0},
            ),
            '266': item(
              typeId: 266,
              groupId: 38,
              baseAttributes: {DogmaAttributes.kineticDamage: 100.0},
            ),
            '22291': ModuleType(
              typeId: 22291,
              name: 'Ballistic Control System II',
              groupId: 51,
              groupName: 'Ballistic Control System',
              slotType: SlotType.low,
              baseAttributes: {213: 1.1},
              effects: const [DogmaEffect(effectId: bcsEffect, name: 'bcs')],
              skillRequirements: const [],
              acceptedChargeGroups: const [],
            ),
          },
          const [],
          effectModifiers: {
            bcsEffect: [
              EffectModifier(
                effectId: bcsEffect,
                func: 'ItemModifier',
                operator: 0,
                modifiedAttributeId: 212,
                modifyingAttributeId: 213,
                domain: 'charID',
              ),
            ],
          },
        );

        expect(stats.volley, closeTo(110, 0.001));
        expect(stats.dpsMissiles, closeTo(55, 0.001));
      },
    );
  });

  group('DogmaEngine capacitor boosters', () {
    late DogmaEngine engine;

    setUp(() {
      engine = DogmaEngine();
    });

    ShipType capShip() => ShipType(
      typeId: 587,
      name: 'Rifter',
      description: 'A Minmatar frigate',
      groupId: 25,
      groupName: 'Frigate',
      baseAttributes: {
        DogmaAttributes.capacitorCapacity: 1000,
        DogmaAttributes.capacitorRechargeTime: 60000,
      },
    );

    Fitting boosterFit({bool loaded = true}) => Fitting(
      id: 'cap',
      name: 'Booster fit',
      shipTypeId: 587,
      shipName: 'Rifter',
      highSlots: [
        FittedModule(
          typeId: 700,
          typeName: 'Test drain',
          slotType: SlotType.high,
          slotIndex: 0,
        ),
      ],
      medSlots: [
        FittedModule(
          typeId: 701,
          typeName: 'Test booster',
          slotType: SlotType.med,
          slotIndex: 0,
          chargeTypeId: loaded ? 702 : null,
          chargeName: loaded ? 'Cap Booster 400' : null,
        ),
      ],
    );

    Map<String, ModuleType> boosterTypes() => {
      '700': ModuleType(
        typeId: 700,
        name: 'Test drain',
        groupId: 1,
        groupName: 'Test',
        slotType: SlotType.high,
        baseAttributes: {
          DogmaAttributes.capacitorNeed: 45.0,
          DogmaAttributes.duration: 1000.0,
        },
        effects: const [],
        skillRequirements: const [],
        acceptedChargeGroups: const [],
      ),
      '701': ModuleType(
        typeId: 701,
        name: 'Test booster',
        groupId: 1,
        groupName: 'Test',
        slotType: SlotType.med,
        baseAttributes: {
          DogmaAttributes.duration: 15000.0,
          DogmaAttributes.reactivationDelay: 10000.0,
        },
        effects: const [],
        skillRequirements: const [],
        acceptedChargeGroups: const [],
      ),
      '702': ModuleType(
        typeId: 702,
        name: 'Cap Booster 400',
        groupId: 1,
        groupName: 'Test',
        slotType: SlotType.high,
        baseAttributes: {DogmaAttributes.capacitorBonus: 400.0},
        effects: const [],
        skillRequirements: const [],
        acceptedChargeGroups: const [],
      ),
    };

    test('a loaded booster stabilizes an otherwise unstable drain', () async {
      final boosted = await engine.calculateStats(
        boosterFit(),
        capShip(),
        boosterTypes(),
        const [],
      );
      final dry = await engine.calculateStats(
        boosterFit(loaded: false),
        capShip(),
        boosterTypes(),
        const [],
      );

      expect(dry.isCapStable, isFalse);
      expect(boosted.isCapStable, isTrue);
    });
  });

  group('DogmaEngine skill cycle bonuses', () {
    late DogmaEngine engine;

    setUp(() {
      engine = DogmaEngine();
    });

    // Published skill / effect / attribute ids from the SDE (design §2.2).
    const gunnery = 3300;
    const rapidFiring = 3310;
    const mlo = 3319;
    const rapidLaunch = 21071;
    const rocketSpec = 20209;
    const lightMissileSpec = 20210;
    const rocketsSkill = 3320;
    const minmatarFrigate = 3329;

    const effectGunnery = 414;
    const effectRapidFiring = 582;
    const effectMlo = 1763;
    const effectSelfRof = 1851;
    const effectShipRof = 7248;
    const effectShipScale = 453;

    const requiredSkill1 = 182;
    const requiredSkill2 = 183;
    const requiredSkill3 = 184;
    const requiredSkill4 = 1285;
    const requiredSkill5 = 1289;
    const requiredSkill6 = 1290;

    const rofBonus = 293;
    const turretSpeeBonus = 441;
    const skillLevel = 280;
    const shipRofAttr = 460;

    const turretTypeId = 561;
    const launcherTypeId = 1120;
    const ammoTypeId = 266;
    const gyroTypeId = 2048;
    const gyroBonusAttr = 1234;

    ModuleType skillItem({
      required int typeId,
      required String name,
      required int effectId,
      required Map<int, double> attributes,
    }) => ModuleType(
      typeId: typeId,
      name: name,
      groupId: 255,
      groupName: 'Skill',
      slotType: SlotType.high,
      baseAttributes: attributes,
      effects: [DogmaEffect(effectId: effectId, name: name)],
    );

    ModuleType turret({
      int typeId = turretTypeId,
      double cycleMs = 3000,
      Map<int, int> requiredSkills = const {requiredSkill2: gunnery},
      Map<int, double> extra = const {},
    }) => ModuleType(
      typeId: typeId,
      name: 'Test turret $typeId',
      groupId: 53,
      groupName: 'Projectile Weapon',
      slotType: SlotType.high,
      baseAttributes: {
        DogmaAttributes.turretDamageMultiplier: 2.0,
        DogmaAttributes.rateOfFire: cycleMs,
        ...requiredSkills.map((id, skill) => MapEntry(id, skill.toDouble())),
        ...extra,
      },
    );

    ModuleType launcher({
      int typeId = launcherTypeId,
      double cycleMs = 4000,
      Map<int, int> requiredSkills = const {requiredSkill1: mlo},
    }) => ModuleType(
      typeId: typeId,
      name: 'Test launcher $typeId',
      groupId: 506,
      groupName: 'Missile Launcher',
      slotType: SlotType.high,
      baseAttributes: {
        DogmaAttributes.rateOfFire: cycleMs,
        ...requiredSkills.map((id, skill) => MapEntry(id, skill.toDouble())),
      },
    );

    ModuleType ammo() => ModuleType(
      typeId: ammoTypeId,
      name: 'Test ammo',
      groupId: 38,
      groupName: 'Ammo',
      slotType: SlotType.high,
      baseAttributes: {DogmaAttributes.kineticDamage: 100.0},
    );

    EffectModifier locationRof({
      required int effectId,
      required int modifyingAttributeId,
      required int skillTypeId,
    }) => EffectModifier(
      effectId: effectId,
      func: 'LocationRequiredSkillModifier',
      operator: 6,
      modifiedAttributeId: DogmaAttributes.rateOfFire,
      modifyingAttributeId: modifyingAttributeId,
      domain: 'shipID',
      skillTypeId: skillTypeId,
    );

    Map<int, ModuleType> rapidFiringSkill() => {
      rapidFiring: skillItem(
        typeId: rapidFiring,
        name: 'Rapid Firing',
        effectId: effectRapidFiring,
        attributes: {rofBonus: -4.0},
      ),
    };

    Map<int, ModuleType> gunnerySkill() => {
      gunnery: skillItem(
        typeId: gunnery,
        name: 'Gunnery',
        effectId: effectGunnery,
        attributes: {turretSpeeBonus: -2.0},
      ),
    };

    Map<int, ModuleType> mloSkill() => {
      mlo: skillItem(
        typeId: mlo,
        name: 'Missile Launcher Operation',
        effectId: effectMlo,
        attributes: {rofBonus: -2.0},
      ),
    };

    Map<int, ModuleType> rapidLaunchSkill() => {
      rapidLaunch: skillItem(
        typeId: rapidLaunch,
        name: 'Rapid Launch',
        effectId: effectMlo,
        attributes: {rofBonus: -3.0},
      ),
    };

    Map<int, ModuleType> rocketSpecSkill({double? extraAttr}) => {
      rocketSpec: skillItem(
        typeId: rocketSpec,
        name: 'Rocket Specialization',
        effectId: effectSelfRof,
        attributes: {rofBonus: -2.0, 999: ?extraAttr},
      ),
    };

    Map<int, ModuleType> lightMissileSpecSkill() => {
      lightMissileSpec: skillItem(
        typeId: lightMissileSpec,
        name: 'Light Missile Specialization',
        effectId: effectSelfRof,
        attributes: {rofBonus: -2.0},
      ),
    };

    Map<int, List<EffectModifier>> turretSkillModifiers() => {
      effectRapidFiring: [
        locationRof(
          effectId: effectRapidFiring,
          modifyingAttributeId: rofBonus,
          skillTypeId: gunnery,
        ),
      ],
      effectGunnery: [
        locationRof(
          effectId: effectGunnery,
          modifyingAttributeId: turretSpeeBonus,
          skillTypeId: gunnery,
        ),
      ],
    };

    Map<int, List<EffectModifier>> launcherSkillModifiers() => {
      effectMlo: [
        locationRof(
          effectId: effectMlo,
          modifyingAttributeId: rofBonus,
          skillTypeId: mlo,
        ),
      ],
    };

    Fitting armed({
      List<int> highs = const [turretTypeId],
      List<int> lows = const [],
      ModuleState state = ModuleState.active,
    }) => Fitting(
      id: 'cycle',
      name: 'Skill cycle fit',
      shipTypeId: 587,
      shipName: 'Rifter',
      highSlots: [
        for (var i = 0; i < highs.length; i++)
          FittedModule(
            typeId: highs[i],
            typeName: 'High $i',
            slotType: SlotType.high,
            slotIndex: i,
            chargeTypeId: ammoTypeId,
            chargeName: 'Test ammo',
            state: state,
          ),
      ],
      lowSlots: [
        for (var i = 0; i < lows.length; i++)
          FittedModule(
            typeId: lows[i],
            typeName: 'Low $i',
            slotType: SlotType.low,
            slotIndex: i,
          ),
      ],
    );

    Future<FittingStats> run({
      required Map<String, ModuleType> modules,
      required List<CharacterSkill> skills,
      required Map<int, ModuleType> skillTypes,
      Map<int, List<EffectModifier>> modifiers = const {},
      ShipType? ship,
      Fitting? fitting,
    }) {
      return engine.calculateStats(
        fitting ?? armed(),
        ship ?? _rifter(),
        {ammoTypeId.toString(): ammo(), ...modules},
        skills,
        effectModifiers: modifiers,
        skillTypes: skillTypes,
      );
    }

    double cycleMs(FittingStats stats) {
      final dps = stats.dpsGuns + stats.dpsMissiles;
      expect(
        dps,
        greaterThan(0),
        reason: 'cannot infer cycle time from zero DPS',
      );
      return stats.volley / dps * 1000.0;
    }

    test(
      'T1.1 Rapid Firing V shortens turret cycle by 4% per level (x0.80)',
      () async {
        final stats = await run(
          modules: {'$turretTypeId': turret()},
          skills: const [CharacterSkill(skillId: rapidFiring, level: 5)],
          skillTypes: rapidFiringSkill(),
          modifiers: turretSkillModifiers(),
        );

        expect(cycleMs(stats), closeTo(2400, 0.01));
        expect(stats.volley, closeTo(200, 0.01));
        expect(stats.dpsGuns, closeTo(200 / 2.4, 0.01));
      },
    );

    test('T1.2 Rapid Firing III scales to x0.88', () async {
      final stats = await run(
        modules: {'$turretTypeId': turret()},
        skills: const [CharacterSkill(skillId: rapidFiring, level: 3)],
        skillTypes: rapidFiringSkill(),
        modifiers: turretSkillModifiers(),
      );

      expect(cycleMs(stats), closeTo(2640, 0.01));
    });

    test('T1.3 untrained Rapid Firing is a no-op', () async {
      final stats = await run(
        modules: {'$turretTypeId': turret()},
        skills: const [],
        skillTypes: rapidFiringSkill(),
        modifiers: turretSkillModifiers(),
      );

      expect(cycleMs(stats), closeTo(3000, 0.01));
      expect(stats.dpsGuns, closeTo(200 / 3.0, 0.01));
    });

    test(
      'T1.1g Gunnery V reduces turret cycle 2%/level; with Rapid Firing V the product is x0.72',
      () async {
        final gunneryOnly = await run(
          modules: {'$turretTypeId': turret()},
          skills: const [CharacterSkill(skillId: gunnery, level: 5)],
          skillTypes: gunnerySkill(),
          modifiers: turretSkillModifiers(),
        );
        expect(cycleMs(gunneryOnly), closeTo(2700, 0.01));

        final both = await run(
          modules: {'$turretTypeId': turret()},
          skills: const [
            CharacterSkill(skillId: gunnery, level: 5),
            CharacterSkill(skillId: rapidFiring, level: 5),
          ],
          skillTypes: {...gunnerySkill(), ...rapidFiringSkill()},
          modifiers: turretSkillModifiers(),
        );
        expect(cycleMs(both), closeTo(3000 * 0.90 * 0.80, 0.01));
        expect(cycleMs(both), closeTo(2160, 0.01));
      },
    );

    test(
      'T1.4 MLO V shortens launcher cycle by 2% per level (x0.90)',
      () async {
        final stats = await run(
          fitting: armed(highs: [launcherTypeId]),
          modules: {'$launcherTypeId': launcher()},
          skills: const [CharacterSkill(skillId: mlo, level: 5)],
          skillTypes: mloSkill(),
          modifiers: launcherSkillModifiers(),
        );

        expect(cycleMs(stats), closeTo(3600, 0.01));
        expect(stats.dpsMissiles, closeTo(100 / 3.6, 0.01));
        expect(stats.dpsGuns, 0.0);
      },
    );

    test(
      'T1.4r Rapid Launch V is x0.85 and composes with MLO V to x0.765',
      () async {
        final launchOnly = await run(
          fitting: armed(highs: [launcherTypeId]),
          modules: {'$launcherTypeId': launcher()},
          skills: const [CharacterSkill(skillId: rapidLaunch, level: 5)],
          skillTypes: rapidLaunchSkill(),
          modifiers: launcherSkillModifiers(),
        );
        expect(cycleMs(launchOnly), closeTo(4000 * 0.85, 0.01));

        final both = await run(
          fitting: armed(highs: [launcherTypeId]),
          modules: {'$launcherTypeId': launcher()},
          skills: const [
            CharacterSkill(skillId: mlo, level: 5),
            CharacterSkill(skillId: rapidLaunch, level: 5),
          ],
          skillTypes: {...mloSkill(), ...rapidLaunchSkill()},
          modifiers: launcherSkillModifiers(),
        );
        expect(cycleMs(both), closeTo(4000 * 0.90 * 0.85, 0.01));
      },
    );

    test(
      'T1.5 Rocket Spec V applies to its T2 launcher when MLO is untrained',
      () async {
        final stats = await run(
          fitting: armed(highs: [launcherTypeId]),
          modules: {
            '$launcherTypeId': launcher(
              requiredSkills: {requiredSkill1: mlo, requiredSkill2: rocketSpec},
            ),
          },
          skills: const [CharacterSkill(skillId: rocketSpec, level: 5)],
          skillTypes: rocketSpecSkill(),
        );

        expect(cycleMs(stats), closeTo(3600, 0.01));
      },
    );

    test('T1.6 MLO V and Rocket Spec V compose multiplicatively', () async {
      final stats = await run(
        fitting: armed(highs: [launcherTypeId]),
        modules: {
          '$launcherTypeId': launcher(
            requiredSkills: {requiredSkill1: mlo, requiredSkill2: rocketSpec},
          ),
        },
        skills: const [
          CharacterSkill(skillId: mlo, level: 5),
          CharacterSkill(skillId: rocketSpec, level: 5),
        ],
        skillTypes: {...mloSkill(), ...rocketSpecSkill()},
        modifiers: launcherSkillModifiers(),
      );

      expect(cycleMs(stats), closeTo(4000 * 0.90 * 0.90, 0.01));
      expect(cycleMs(stats), isNot(closeTo(4000 * 0.80, 0.01)));
    });

    test(
      'T1.7 Rocket Spec does not leak onto a launcher that requires Light Missile Spec',
      () async {
        final stats = await run(
          fitting: armed(highs: [launcherTypeId]),
          modules: {
            '$launcherTypeId': launcher(
              requiredSkills: {requiredSkill1: mlo, requiredSkill2: rocketSpec},
            ),
          },
          skills: const [CharacterSkill(skillId: lightMissileSpec, level: 5)],
          skillTypes: lightMissileSpecSkill(),
        );

        expect(cycleMs(stats), closeTo(4000, 0.01));
      },
    );

    test(
      'T1.8 Rocket Spec skips a T1 launcher that does not require it',
      () async {
        final stats = await run(
          fitting: armed(highs: [launcherTypeId]),
          modules: {
            '$launcherTypeId': launcher(
              requiredSkills: {
                requiredSkill1: mlo,
                requiredSkill2: rocketsSkill,
              },
            ),
          },
          skills: const [CharacterSkill(skillId: rocketSpec, level: 5)],
          skillTypes: rocketSpecSkill(),
        );

        expect(cycleMs(stats), closeTo(4000, 0.01));
      },
    );

    test('T1.9 Rapid Firing does not shorten missile launchers', () async {
      final stats = await run(
        fitting: armed(highs: [launcherTypeId]),
        modules: {'$launcherTypeId': launcher()},
        skills: const [CharacterSkill(skillId: rapidFiring, level: 5)],
        skillTypes: rapidFiringSkill(),
        modifiers: {...turretSkillModifiers(), ...launcherSkillModifiers()},
      );

      expect(cycleMs(stats), closeTo(4000, 0.01));
    });

    test('T1.10 MLO does not shorten turrets', () async {
      final stats = await run(
        modules: {'$turretTypeId': turret()},
        skills: const [CharacterSkill(skillId: mlo, level: 5)],
        skillTypes: mloSkill(),
        modifiers: {...turretSkillModifiers(), ...launcherSkillModifiers()},
      );

      expect(cycleMs(stats), closeTo(3000, 0.01));
    });

    test(
      'T1.11 Rapid Firing applies when Gunnery is only in requiredSkill4 (1285)',
      () async {
        final stats = await run(
          modules: {
            '$turretTypeId': turret(requiredSkills: {requiredSkill4: gunnery}),
          },
          skills: const [CharacterSkill(skillId: rapidFiring, level: 5)],
          skillTypes: rapidFiringSkill(),
          modifiers: turretSkillModifiers(),
        );

        expect(cycleMs(stats), closeTo(2400, 0.01));
      },
    );

    test(
      'T1.12 Vorton-shaped required skills receive no Rapid Firing bonus',
      () async {
        final stats = await run(
          modules: {
            '$turretTypeId': turret(
              requiredSkills: {
                requiredSkill1: 55033,
                requiredSkill2: 54826,
                requiredSkill3: 54829,
              },
            ),
          },
          skills: const [CharacterSkill(skillId: rapidFiring, level: 5)],
          skillTypes: rapidFiringSkill(),
          modifiers: turretSkillModifiers(),
        );

        expect(cycleMs(stats), closeTo(3000, 0.01));
      },
    );

    test('T1.12b probe and bomb launchers receive no cycle bonus', () async {
      const probeId = 17901;
      const bombId = 27914;
      final stats = await run(
        fitting: armed(highs: [probeId, bombId]),
        modules: {
          '$probeId': launcher(
            typeId: probeId,
            requiredSkills: {requiredSkill1: 3406},
          ),
          '$bombId': launcher(
            typeId: bombId,
            requiredSkills: {requiredSkill1: 3409},
          ),
        },
        skills: const [
          CharacterSkill(skillId: rapidFiring, level: 5),
          CharacterSkill(skillId: mlo, level: 5),
          CharacterSkill(skillId: rocketSpec, level: 5),
        ],
        skillTypes: {
          ...rapidFiringSkill(),
          ...mloSkill(),
          ...rocketSpecSkill(),
        },
        modifiers: {...turretSkillModifiers(), ...launcherSkillModifiers()},
      );

      expect(cycleMs(stats), closeTo(4000, 0.01));
      expect(stats.volley, closeTo(200, 0.01));
    });

    test(
      'T1.13 ship trait ROF composes with Gunnery V and Rapid Firing V',
      () async {
        final ship = _rifter().copyWith(
          effects: const [
            DogmaEffect(effectId: effectShipRof, name: 'ship rof'),
            DogmaEffect(effectId: effectShipScale, name: 'scale'),
          ],
          baseAttributes: {
            ..._rifter().baseAttributes,
            requiredSkill1: minmatarFrigate.toDouble(),
            shipRofAttr: -7.5,
          },
        );
        final racial = skillItem(
          typeId: minmatarFrigate,
          name: 'Minmatar Frigate',
          effectId: effectShipScale,
          attributes: {skillLevel: 1.0},
        );
        final stats = await run(
          ship: ship,
          modules: {'$turretTypeId': turret()},
          skills: const [
            CharacterSkill(skillId: minmatarFrigate, level: 5),
            CharacterSkill(skillId: gunnery, level: 5),
            CharacterSkill(skillId: rapidFiring, level: 5),
          ],
          skillTypes: {
            minmatarFrigate: racial,
            ...gunnerySkill(),
            ...rapidFiringSkill(),
          },
          modifiers: {
            ...turretSkillModifiers(),
            effectShipRof: [
              locationRof(
                effectId: effectShipRof,
                modifyingAttributeId: shipRofAttr,
                skillTypeId: gunnery,
              ),
            ],
            effectShipScale: [
              EffectModifier(
                effectId: effectShipScale,
                func: 'ItemModifier',
                operator: 0,
                modifiedAttributeId: shipRofAttr,
                modifyingAttributeId: skillLevel,
                domain: 'shipID',
              ),
            ],
          },
        );

        expect(cycleMs(stats), closeTo(3000 * 0.625 * 0.90 * 0.80, 0.01));
      },
    );

    test(
      'T1.14 ship and skill ROF bonuses are unpenalized: product of factors exactly',
      () async {
        final ship = _rifter().copyWith(
          effects: const [
            DogmaEffect(effectId: effectShipRof, name: 'ship rof'),
            DogmaEffect(effectId: effectShipScale, name: 'scale'),
          ],
          baseAttributes: {
            ..._rifter().baseAttributes,
            requiredSkill1: minmatarFrigate.toDouble(),
            shipRofAttr: -7.5,
          },
        );
        final stats = await run(
          ship: ship,
          modules: {'$turretTypeId': turret()},
          skills: const [
            CharacterSkill(skillId: minmatarFrigate, level: 5),
            CharacterSkill(skillId: gunnery, level: 5),
            CharacterSkill(skillId: rapidFiring, level: 5),
          ],
          skillTypes: {
            minmatarFrigate: skillItem(
              typeId: minmatarFrigate,
              name: 'Minmatar Frigate',
              effectId: effectShipScale,
              attributes: {skillLevel: 1.0},
            ),
            ...gunnerySkill(),
            ...rapidFiringSkill(),
          },
          modifiers: {
            ...turretSkillModifiers(),
            effectShipRof: [
              locationRof(
                effectId: effectShipRof,
                modifyingAttributeId: shipRofAttr,
                skillTypeId: gunnery,
              ),
            ],
            effectShipScale: [
              EffectModifier(
                effectId: effectShipScale,
                func: 'ItemModifier',
                operator: 0,
                modifiedAttributeId: shipRofAttr,
                modifyingAttributeId: skillLevel,
                domain: 'shipID',
              ),
            ],
          },
        );

        final expected = 3000 * 0.625 * 0.90 * 0.80;
        expect(cycleMs(stats), closeTo(expected, 0.01));
        expect(
          cycleMs(stats),
          isNot(closeTo(expected * DogmaEngine.getStackingPenalty(2), 0.5)),
          reason: 'a stacking penalty on the second skill/ship bonus is a bug',
        );
      },
    );

    test(
      'T1.14m two module-owned ROF bonuses are stacking-penalized; skills are not',
      () async {
        const gyroEffect = 91;
        final gyro = ModuleType(
          typeId: gyroTypeId,
          name: 'Cycle gyro',
          groupId: 59,
          groupName: 'Gyrostabilizer',
          slotType: SlotType.low,
          baseAttributes: {gyroBonusAttr: 0.9},
          effects: const [DogmaEffect(effectId: gyroEffect, name: 'gyro rof')],
        );
        final stats = await run(
          fitting: armed(lows: [gyroTypeId, gyroTypeId]),
          modules: {'$turretTypeId': turret(), '$gyroTypeId': gyro},
          skills: const [
            CharacterSkill(skillId: gunnery, level: 5),
            CharacterSkill(skillId: rapidFiring, level: 5),
          ],
          skillTypes: {...gunnerySkill(), ...rapidFiringSkill()},
          modifiers: {
            ...turretSkillModifiers(),
            gyroEffect: [
              EffectModifier(
                effectId: gyroEffect,
                func: 'LocationRequiredSkillModifier',
                operator: 4,
                modifiedAttributeId: DogmaAttributes.rateOfFire,
                modifyingAttributeId: gyroBonusAttr,
                domain: 'shipID',
                skillTypeId: gunnery,
              ),
            ],
          },
        );

        final secondPenalty = DogmaEngine.getStackingPenalty(2);
        final moduleChain = 0.9 * (1 + (0.9 - 1) * secondPenalty);
        final expected = 3000 * moduleChain * 0.90 * 0.80;
        expect(cycleMs(stats), closeTo(expected, 0.01));

        final unpenalizedModules = 3000 * 0.9 * 0.9 * 0.90 * 0.80;
        expect(
          cycleMs(stats),
          isNot(closeTo(unpenalizedModules, 0.5)),
          reason: 'the second module-owned bonus must take exp(-(i/2.67)^2)',
        );
      },
    );

    test('T1.15 Rapid Firing leaves volley unchanged', () async {
      final untrained = await run(
        modules: {'$turretTypeId': turret()},
        skills: const [],
        skillTypes: rapidFiringSkill(),
        modifiers: turretSkillModifiers(),
      );
      final trained = await run(
        modules: {'$turretTypeId': turret()},
        skills: const [CharacterSkill(skillId: rapidFiring, level: 5)],
        skillTypes: rapidFiringSkill(),
        modifiers: turretSkillModifiers(),
      );

      expect(trained.volley, closeTo(untrained.volley, 0.01));
      expect(trained.dpsGuns, greaterThan(untrained.dpsGuns));
    });

    test('T1.16 cap drain uses the shortened rateOfFire cycle', () async {
      final ship = _rifter().copyWith(
        baseAttributes: {
          ..._rifter().baseAttributes,
          DogmaAttributes.capacitorCapacity: 500.0,
          DogmaAttributes.capacitorRechargeTime: 120000.0,
        },
      );
      final hungry = turret(extra: {DogmaAttributes.capacitorNeed: 28.0});
      final untrained = await run(
        ship: ship,
        modules: {'$turretTypeId': hungry},
        skills: const [],
        skillTypes: rapidFiringSkill(),
        modifiers: turretSkillModifiers(),
      );
      final trained = await run(
        ship: ship,
        modules: {'$turretTypeId': hungry},
        skills: const [CharacterSkill(skillId: rapidFiring, level: 5)],
        skillTypes: rapidFiringSkill(),
        modifiers: turretSkillModifiers(),
      );

      expect(cycleMs(trained), closeTo(2400, 0.01));
      expect(untrained.isCapStable, isTrue);
      expect(trained.isCapStable, isFalse);
    });

    test(
      'T1.17 offline turrets receive no skill cycle bonus and no DPS',
      () async {
        final stats = await run(
          fitting: armed(state: ModuleState.offline),
          modules: {
            '$turretTypeId': turret(
              extra: {DogmaAttributes.capacitorNeed: 28.0},
            ),
          },
          skills: const [CharacterSkill(skillId: rapidFiring, level: 5)],
          skillTypes: rapidFiringSkill(),
          modifiers: turretSkillModifiers(),
        );

        expect(stats.dpsGuns, 0.0);
        expect(stats.dpsTotal, 0.0);
        expect(stats.volley, 0.0);
      },
    );

    test(
      'T1.18 a skill type without attr 293 applies no bonus and does not throw',
      () async {
        final stats = await run(
          modules: {'$turretTypeId': turret()},
          skills: const [CharacterSkill(skillId: rapidFiring, level: 5)],
          skillTypes: {
            rapidFiring: skillItem(
              typeId: rapidFiring,
              name: 'Rapid Firing',
              effectId: effectRapidFiring,
              attributes: const {},
            ),
          },
          modifiers: turretSkillModifiers(),
        );

        expect(cycleMs(stats), closeTo(3000, 0.01));
      },
    );

    test('T1.19 recorded level 7 is clamped to 5', () async {
      final over = await run(
        modules: {'$turretTypeId': turret()},
        skills: const [CharacterSkill(skillId: rapidFiring, level: 7)],
        skillTypes: rapidFiringSkill(),
        modifiers: turretSkillModifiers(),
      );
      final five = await run(
        modules: {'$turretTypeId': turret()},
        skills: const [CharacterSkill(skillId: rapidFiring, level: 5)],
        skillTypes: rapidFiringSkill(),
        modifiers: turretSkillModifiers(),
      );

      expect(cycleMs(over), closeTo(2400, 0.01));
      expect(cycleMs(over), closeTo(cycleMs(five), 0.01));
      expect(
        cycleMs(over),
        isNot(closeTo(3000 * (1 + (-4 * 7) / 100), 0.5)),
        reason: 'level 7 must not apply as x1.28 of a reduction',
      );
    });

    test(
      'T1.23 curated effect 1851 yields to a non-empty bundled modifier list',
      () async {
        final stats = await run(
          fitting: armed(highs: [launcherTypeId]),
          modules: {
            '$launcherTypeId': launcher(
              requiredSkills: {requiredSkill1: mlo, requiredSkill2: rocketSpec},
            ),
          },
          skills: const [CharacterSkill(skillId: rocketSpec, level: 5)],
          skillTypes: rocketSpecSkill(extraAttr: -1.0),
          modifiers: {
            effectSelfRof: [
              locationRof(
                effectId: effectSelfRof,
                modifyingAttributeId: 999,
                skillTypeId: rocketSpec,
              ),
            ],
          },
        );

        // Bundled modifier uses attr 999 = -1 => x0.95 at V.
        // Curated 1851 would use attr 293 = -2 => x0.90.
        expect(cycleMs(stats), closeTo(4000 * 0.95, 0.01));
        expect(cycleMs(stats), isNot(closeTo(3600, 0.5)));
        expect(cycleMs(stats), isNot(closeTo(4000 * 0.95 * 0.90, 0.5)));
      },
    );

    test(
      'T1.24 a non-allowlisted skill effect is ignored and does not change cycle',
      () async {
        const otherSkill = 9999;
        const otherEffect = 8888;
        final stats = await run(
          modules: {'$turretTypeId': turret()},
          skills: const [CharacterSkill(skillId: otherSkill, level: 5)],
          skillTypes: {
            otherSkill: skillItem(
              typeId: otherSkill,
              name: 'Not allowlisted',
              effectId: otherEffect,
              attributes: {rofBonus: -50.0},
            ),
          },
          modifiers: {
            otherEffect: [
              locationRof(
                effectId: otherEffect,
                modifyingAttributeId: rofBonus,
                skillTypeId: gunnery,
              ),
            ],
          },
        );

        expect(cycleMs(stats), closeTo(3000, 0.01));
      },
    );

    test(
      'T1.25 Rapid Firing honours required-skill slots 1289 and 1290',
      () async {
        const slot5Turret = 5611;
        const slot6Turret = 5612;
        final stats = await run(
          fitting: armed(highs: [slot5Turret, slot6Turret]),
          modules: {
            '$slot5Turret': turret(
              typeId: slot5Turret,
              requiredSkills: {requiredSkill5: gunnery},
            ),
            '$slot6Turret': turret(
              typeId: slot6Turret,
              requiredSkills: {requiredSkill6: gunnery},
            ),
          },
          skills: const [CharacterSkill(skillId: rapidFiring, level: 5)],
          skillTypes: rapidFiringSkill(),
          modifiers: turretSkillModifiers(),
        );

        expect(stats.volley, closeTo(400, 0.01));
        expect(stats.dpsGuns, closeTo(400 / 2.4, 0.01));
        expect(cycleMs(stats), closeTo(2400, 0.01));
      },
    );
  });

  group('DogmaEngine fighters', () {
    late DogmaEngine engine;

    setUp(() {
      engine = DogmaEngine();
    });

    const fightersSkill = 23069;
    const dronesSkill = 3436;
    const capitalShips = 20533;
    const gallenteCarrier = 24313;
    const droneInterfacing = 3442;
    const fhmSkill = 24613;
    const ddaEffect = 6556;
    const hullFighterEffect = 6601;
    const carrierScaleEffect = 6585;
    const fightersEffect = 6560;
    const interfacingEffect = 6663;
    const fhmEffect = 6570;
    const attackEffect = 6465;
    const missilesEffect = 6431;
    const mwdEffect = 6441;
    const evasiveEffect = 6439;
    const tackleEffect = 6464;
    const bombEffect = 6485;
    const mjdEffect = 6442;
    const hullBonusAttr = 2367;
    const ddaBonusAttr = 1255;
    const damageBonusAttr = 292;
    const hangarBonusAttr = 2340;

    ShipType carrierShip({
      double tubes = 4,
      double light = 3,
      double support = 2,
      double heavy = 2,
      double bay = 75000,
      Map<int, double> extra = const {},
      List<DogmaEffect> effects = const [],
    }) => ShipType(
      typeId: 23911,
      name: 'Carrier',
      description: '',
      groupId: 547,
      groupName: 'Carrier',
      effects: effects,
      baseAttributes: {
        ..._rifter().baseAttributes,
        DogmaAttributes.fighterTubes: tubes,
        DogmaAttributes.fighterLightSlots: light,
        DogmaAttributes.fighterSupportSlots: support,
        DogmaAttributes.fighterHeavySlots: heavy,
        DogmaAttributes.fighterCapacity: bay,
        DogmaAttributes.droneBandwidth: 25,
        DogmaAttributes.droneCapacity: 40,
        ...extra,
      },
    );

    ModuleType fighterType({
      int typeId = 23059,
      double size = 6,
      double em = 0,
      double thermal = 207,
      double kinetic = 0,
      double explosive = 0,
      double multiplier = 1.0,
      double durationMs = 5000,
      bool light = true,
      bool support = false,
      bool heavy = false,
      bool standup = false,
      double volume = 1000,
      List<int> effectIds = const [attackEffect],
      Map<int, double> extra = const {},
    }) => ModuleType(
      typeId: typeId,
      name: 'Fighter $typeId',
      groupId: light
          ? 1652
          : support
          ? 1537
          : 1653,
      groupName: 'Fighter',
      slotType: SlotType.high,
      baseAttributes: {
        DogmaAttributes.fighterSquadronMaxSize: size,
        if (light) DogmaAttributes.fighterSquadronIsLight: 1.0,
        if (support) DogmaAttributes.fighterSquadronIsSupport: 1.0,
        if (heavy) DogmaAttributes.fighterSquadronIsHeavy: 1.0,
        if (standup) 2740: 1.0,
        DogmaAttributes.fighterEmDamage: em,
        DogmaAttributes.fighterThermalDamage: thermal,
        DogmaAttributes.fighterKineticDamage: kinetic,
        DogmaAttributes.fighterExplosiveDamage: explosive,
        DogmaAttributes.fighterDamageMultiplier: multiplier,
        DogmaAttributes.fighterDurationMs: durationMs,
        DogmaAttributes.volume: volume,
        182: fightersSkill.toDouble(),
        ...extra,
      },
      effects: [
        for (final id in effectIds) DogmaEffect(effectId: id, name: 'e$id'),
      ],
    );

    ModuleType droneType() => ModuleType(
      typeId: 2488,
      name: 'Warrior II',
      groupId: 100,
      groupName: 'Combat Drone',
      slotType: SlotType.high,
      baseAttributes: {
        DogmaAttributes.explosiveDamage: 10.0,
        DogmaAttributes.turretDamageMultiplier: 2.0,
        DogmaAttributes.rateOfFire: 4000.0,
        DogmaAttributes.bandwidthNeeded: 5.0,
        DogmaAttributes.volume: 5.0,
        184: dronesSkill.toDouble(),
      },
    );

    ModuleType gunType() => ModuleType(
      typeId: 561,
      name: 'Gun',
      groupId: 53,
      groupName: 'Projectile',
      slotType: SlotType.high,
      baseAttributes: {
        DogmaAttributes.turretDamageMultiplier: 2.0,
        DogmaAttributes.rateOfFire: 4000.0,
      },
    );

    ModuleType ammoType() => ModuleType(
      typeId: 266,
      name: 'Ammo',
      groupId: 38,
      groupName: 'Ammo',
      slotType: SlotType.high,
      baseAttributes: {DogmaAttributes.kineticDamage: 100.0},
    );

    FighterGroup sq({int typeId = 23059, int quantity = 6, int inSpace = 0}) =>
        FighterGroup(
          typeId: typeId,
          typeName: 'Fighter $typeId',
          quantity: quantity,
          inSpace: inSpace,
        );

    Fitting fit({
      List<FighterGroup> fighters = const [],
      List<DroneGroup> drones = const [],
      List<FittedModule> high = const [],
      List<FittedModule> low = const [],
    }) => Fitting(
      id: 'fighters',
      name: 'Fighter fit',
      shipTypeId: 23911,
      shipName: 'Carrier',
      highSlots: high,
      lowSlots: low,
      drones: drones,
      fighters: fighters,
    );

    Future<FittingStats> run({
      required Map<String, ModuleType> modules,
      Fitting? fitting,
      ShipType? ship,
      List<CharacterSkill> skills = const [],
      Map<int, ModuleType> skillTypes = const {},
      Map<int, List<EffectModifier>> modifiers = const {},
    }) {
      return engine.calculateStats(
        fitting ?? fit(fighters: [sq()]),
        ship ?? carrierShip(),
        modules,
        skills,
        effectModifiers: modifiers,
        skillTypes: skillTypes,
      );
    }

    test(
      'T2.1 squadron DPS is size x thermal / (duration ms / 1000)',
      () async {
        final stats = await run(modules: {'23059': fighterType()});
        expect(stats.dpsFighters, closeTo(6 * 207 / 5, 0.01));
        expect(stats.dpsFighters, closeTo(248.4, 0.01));
      },
    );

    test('T2.2 squadron size 9 vs 6 scales DPS by 1.5', () async {
      final six = await run(modules: {'23059': fighterType()});
      final nine = await run(
        fitting: fit(fighters: [sq(quantity: 9)]),
        modules: {'23059': fighterType(size: 9)},
      );
      expect(nine.dpsFighters / six.dpsFighters, closeTo(1.5, 0.001));
    });

    test('T2.3 damage multiplier 1.5 scales DPS by 1.5', () async {
      final base = await run(modules: {'23059': fighterType()});
      expect(base.dpsFighters, greaterThan(0));
      final boosted = await run(
        modules: {'23059': fighterType(multiplier: 1.5)},
      );
      expect(boosted.dpsFighters, closeTo(base.dpsFighters * 1.5, 0.01));
    });

    test('T2.4 duration 5000 ms divides by 5.0 seconds, not 5000', () async {
      final stats = await run(modules: {'23059': fighterType()});
      expect(stats.dpsFighters, closeTo(248.4, 0.01));
      expect(stats.dpsFighters, isNot(closeTo(6 * 207 / 5000, 0.01)));
    });

    test(
      'T2.5 four damage components of 50 sum to volley 200 x size',
      () async {
        final stats = await run(
          modules: {
            '23059': fighterType(
              em: 50,
              thermal: 50,
              kinetic: 50,
              explosive: 50,
            ),
          },
        );
        expect(stats.dpsFighters, closeTo(200 * 6 / 5.0, 0.01));
      },
    );

    test('T2.6 tube cap 4 binds five light squadrons', () async {
      final stats = await run(
        ship: carrierShip(tubes: 4, light: 8),
        fitting: fit(fighters: [for (var i = 0; i < 5; i++) sq()]),
        modules: {'23059': fighterType()},
      );
      expect(stats.fighterTubesUsed, 4);
      expect(stats.fighterTubesMax, 4);
      expect(stats.dpsFighters, closeTo(4 * 248.4, 0.01));
    });

    test('T2.7 heavy class cap 2 binds three heavy squadrons', () async {
      final stats = await run(
        ship: carrierShip(tubes: 4, heavy: 2),
        fitting: fit(fighters: [for (var i = 0; i < 3; i++) sq(typeId: 32325)]),
        modules: {
          '32325': fighterType(typeId: 32325, light: false, heavy: true),
        },
      );
      expect(stats.fighterHeavyUsed, 2);
      expect(stats.fighterHeavyMax, 2);
      expect(stats.dpsFighters, closeTo(2 * 248.4, 0.01));
    });

    test(
      'T2.8 Nyx-shaped support cap 0 launches no support squadron',
      () async {
        final stats = await run(
          ship: carrierShip(tubes: 5, light: 3, support: 0, heavy: 4),
          fitting: fit(fighters: [sq(typeId: 40347, quantity: 3)]),
          modules: {
            '40347': fighterType(
              typeId: 40347,
              size: 3,
              light: false,
              support: true,
            ),
          },
        );
        expect(stats.fighterSupportUsed, 0);
        expect(stats.fighterSupportMax, 0);
        expect(stats.dpsFighters, 0);
      },
    );

    test('T2.9 tubes 4 win over light cap 5', () async {
      final stats = await run(
        ship: carrierShip(tubes: 4, light: 5),
        fitting: fit(fighters: [for (var i = 0; i < 5; i++) sq()]),
        modules: {'23059': fighterType()},
      );
      expect(stats.fighterTubesUsed, 4);
      expect(stats.fighterLightUsed, 4);
      expect(stats.dpsFighters, closeTo(4 * 248.4, 0.01));
    });

    test(
      'T2.10 mixed classes activate in declaration order until tubes empty',
      () async {
        final stats = await run(
          ship: carrierShip(tubes: 4, light: 3, support: 2, heavy: 2),
          fitting: fit(
            fighters: [
              sq(typeId: 1),
              sq(typeId: 1),
              sq(typeId: 2),
              sq(typeId: 2),
              sq(typeId: 3),
              sq(typeId: 3),
            ],
          ),
          modules: {
            '1': fighterType(typeId: 1),
            '2': fighterType(typeId: 2, light: false, heavy: true),
            '3': fighterType(typeId: 3, light: false, support: true),
          },
        );
        expect(stats.fighterTubesUsed, 4);
        expect(stats.fighterLightUsed, 2);
        expect(stats.fighterHeavyUsed, 2);
        expect(stats.fighterSupportUsed, 0);
      },
    );

    test('T2.6q quantity 14 yields squadrons 6/6/2 all active', () async {
      final stats = await run(
        ship: carrierShip(tubes: 3, light: 3),
        fitting: fit(fighters: [sq(quantity: 14)]),
        modules: {'23059': fighterType()},
      );
      expect(stats.fighterTubesUsed, 3);
      expect(stats.fighterSquadrons.single.squadrons, 3);
      expect(stats.fighterSquadrons.single.activeSquadrons, 3);
      expect(stats.dpsFighters, closeTo(14 / 6 * 248.4, 0.01));
    });

    test(
      'T2.6s inSpace 6 of 12 launches one squadron; bay still counts 12',
      () async {
        final stats = await run(
          fitting: fit(fighters: [sq(quantity: 12, inSpace: 6)]),
          modules: {'23059': fighterType(volume: 1000)},
        );
        expect(stats.fighterTubesUsed, 1);
        expect(stats.dpsFighters, closeTo(248.4, 0.01));
        expect(stats.fighterBayUsed, closeTo(12000, 0.01));
      },
    );

    test('T2.11 bay usage is 3 squadrons x 6 x 1000 m3', () async {
      final stats = await run(
        fitting: fit(fighters: [sq(), sq(), sq()]),
        modules: {'23059': fighterType(volume: 1000)},
      );
      expect(stats.fighterBayUsed, closeTo(18000, 0.01));
    });

    test(
      'T2.12 bay over-capacity is reported and does not truncate DPS',
      () async {
        final stats = await run(
          ship: carrierShip(bay: 10000),
          fitting: fit(fighters: [sq(), sq(), sq()]),
          modules: {'23059': fighterType(volume: 1000)},
        );
        expect(stats.fighterBayUsed, closeTo(18000, 0.01));
        expect(stats.fighterBayMax, closeTo(10000, 0.01));
        expect(stats.dpsFighters, closeTo(3 * 248.4, 0.01));
      },
    );

    test(
      'T2.13 drones on a fighter hull keep drone stats bit-identical',
      () async {
        final dronesOnly = await run(
          fitting: fit(
            drones: [
              const DroneGroup(
                typeId: 2488,
                typeName: 'Warrior II',
                quantity: 5,
              ),
            ],
          ),
          modules: {'2488': droneType()},
        );
        final both = await run(
          fitting: fit(
            drones: [
              const DroneGroup(
                typeId: 2488,
                typeName: 'Warrior II',
                quantity: 5,
              ),
            ],
            fighters: [sq()],
          ),
          modules: {'2488': droneType(), '23059': fighterType()},
        );
        expect(both.dpsDrones, dronesOnly.dpsDrones);
        expect(both.droneBandwidthUsed, dronesOnly.droneBandwidthUsed);
        expect(both.droneBayUsed, dronesOnly.droneBayUsed);
        expect(both.dpsFighters, closeTo(248.4, 0.01));
      },
    );

    test('T2.14 fighters never consume drone bandwidth', () async {
      final stats = await run(modules: {'23059': fighterType()});
      expect(stats.droneBandwidthUsed, 0);
    });

    test('T2.15 dpsTotal sums guns, drones and fighters once', () async {
      final stats = await run(
        fitting: fit(
          high: [
            const FittedModule(
              typeId: 561,
              typeName: 'Gun',
              slotType: SlotType.high,
              slotIndex: 0,
              chargeTypeId: 266,
              chargeName: 'Ammo',
            ),
          ],
          drones: [
            const DroneGroup(typeId: 2488, typeName: 'Warrior II', quantity: 5),
          ],
          fighters: [sq()],
        ),
        modules: {
          '561': gunType(),
          '266': ammoType(),
          '2488': droneType(),
          '23059': fighterType(),
        },
      );
      expect(
        stats.dpsTotal,
        closeTo(
          stats.dpsGuns +
              stats.dpsMissiles +
              stats.dpsDrones +
              stats.dpsFighters,
          0.01,
        ),
      );
      expect(stats.dpsGuns, greaterThan(0));
      expect(stats.dpsDrones, greaterThan(0));
      expect(stats.dpsFighters, greaterThan(0));
    });

    test(
      'T2.16 Rifter plus fighters reports zero fighter fields and does not throw',
      () async {
        final stats = await run(
          ship: _rifter(),
          fitting: Fitting(
            id: 'rifter',
            name: 'Rifter',
            shipTypeId: 587,
            shipName: 'Rifter',
            fighters: [sq()],
          ),
          modules: {'23059': fighterType()},
        );
        expect(stats.dpsFighters, 0);
        expect(stats.fighterTubesUsed, 0);
        expect(stats.fighterTubesMax, 0);
        expect(stats.fighterBayUsed, 0);
        expect(stats.fighterBayMax, 0);
        expect(stats.fighterLightUsed, 0);
        expect(stats.fighterSupportUsed, 0);
        expect(stats.fighterHeavyUsed, 0);
      },
    );

    test(
      'T2.17 missing 2215 or 2233 contributes 0 and does not throw',
      () async {
        final noSize = fighterType().copyWith(
          baseAttributes: {...fighterType().baseAttributes}
            ..remove(DogmaAttributes.fighterSquadronMaxSize),
        );
        final noDuration = fighterType(typeId: 99).copyWith(
          baseAttributes: {...fighterType(typeId: 99).baseAttributes}
            ..remove(DogmaAttributes.fighterDurationMs),
        );
        final stats = await run(
          fitting: fit(fighters: [sq(), sq(typeId: 99)]),
          modules: {'23059': noSize, '99': noDuration},
        );
        expect(stats.dpsFighters, 0);
      },
    );

    test('T2.18 DDA II boosts fighters and drones by x1.205', () async {
      final dda = ModuleType(
        typeId: 4405,
        name: 'DDA II',
        groupId: 646,
        groupName: 'Drone Damage Amplifier',
        slotType: SlotType.low,
        baseAttributes: {ddaBonusAttr: 20.5},
        effects: const [DogmaEffect(effectId: ddaEffect, name: 'dda')],
      );
      final modifiers = {
        ddaEffect: [
          EffectModifier(
            effectId: ddaEffect,
            func: 'OwnerRequiredSkillModifier',
            operator: 6,
            modifiedAttributeId: DogmaAttributes.fighterDamageMultiplier,
            modifyingAttributeId: ddaBonusAttr,
            domain: 'charID',
            skillTypeId: fightersSkill,
          ),
          EffectModifier(
            effectId: ddaEffect,
            func: 'OwnerRequiredSkillModifier',
            operator: 6,
            modifiedAttributeId: DogmaAttributes.turretDamageMultiplier,
            modifyingAttributeId: ddaBonusAttr,
            domain: 'charID',
            skillTypeId: dronesSkill,
          ),
        ],
      };
      final stats = await run(
        fitting: fit(
          low: [
            const FittedModule(
              typeId: 4405,
              typeName: 'DDA II',
              slotType: SlotType.low,
              slotIndex: 0,
            ),
          ],
          drones: [
            const DroneGroup(typeId: 2488, typeName: 'Warrior II', quantity: 5),
          ],
          fighters: [sq()],
        ),
        modules: {'23059': fighterType(), '2488': droneType(), '4405': dda},
        modifiers: modifiers,
      );
      expect(stats.dpsFighters, closeTo(248.4 * 1.205, 0.01));
      expect(stats.dpsDrones, closeTo(25 * 1.205, 0.01));
    });

    test('T2.18b two DDAs stacking-penalize the second bonus', () async {
      final dda = ModuleType(
        typeId: 4405,
        name: 'DDA II',
        groupId: 646,
        groupName: 'Drone Damage Amplifier',
        slotType: SlotType.low,
        baseAttributes: {ddaBonusAttr: 20.5},
        effects: const [DogmaEffect(effectId: ddaEffect, name: 'dda')],
      );
      final stats = await run(
        fitting: fit(
          low: [
            const FittedModule(
              typeId: 4405,
              typeName: 'DDA II',
              slotType: SlotType.low,
              slotIndex: 0,
            ),
            const FittedModule(
              typeId: 4405,
              typeName: 'DDA II',
              slotType: SlotType.low,
              slotIndex: 1,
            ),
          ],
          fighters: [sq()],
        ),
        modules: {'23059': fighterType(), '4405': dda},
        modifiers: {
          ddaEffect: [
            EffectModifier(
              effectId: ddaEffect,
              func: 'OwnerRequiredSkillModifier',
              operator: 6,
              modifiedAttributeId: DogmaAttributes.fighterDamageMultiplier,
              modifyingAttributeId: ddaBonusAttr,
              domain: 'charID',
              skillTypeId: fightersSkill,
            ),
          ],
        },
      );
      final second = DogmaEngine.getStackingPenalty(2);
      final expected = 248.4 * (1 + 0.205) * (1 + 0.205 * second);
      expect(stats.dpsFighters, closeTo(expected, 0.01));
    });

    test(
      'T2.19 Firbolg shape uses attack DPS; missiles and MWD are listed',
      () async {
        final stats = await run(
          modules: {
            '23059': fighterType(
              effectIds: const [attackEffect, missilesEffect, mwdEffect],
              extra: {
                DogmaAttributes.fighterMissilesThermalDamage: 207.0,
                DogmaAttributes.fighterMissilesDamageMultiplier: 1.0,
                DogmaAttributes.fighterMissilesDurationMs: 14000.0,
              },
            ),
          },
        );
        expect(stats.dpsFighters, closeTo(248.4, 0.01));
        final row = stats.fighterSquadrons.single;
        expect(
          row.abilities,
          containsAll([
            FighterAbilityKind.attack,
            FighterAbilityKind.missiles,
            FighterAbilityKind.microWarpDrive,
          ]),
        );
        expect(row.activeAbility, FighterAbilityKind.attack);
      },
    );

    test('T2.19g Gram shape (no attack) uses missiles DPS', () async {
      final stats = await run(
        fitting: fit(fighters: [sq(typeId: 40361, quantity: 12)]),
        modules: {
          '40361': fighterType(
            typeId: 40361,
            size: 12,
            thermal: 0,
            durationMs: 3500,
            effectIds: const [missilesEffect, evasiveEffect, tackleEffect],
            extra: {
              DogmaAttributes.fighterSquadronRole: 1.0,
              DogmaAttributes.fighterMissilesExplosiveDamage: 36.0,
              DogmaAttributes.fighterMissilesDamageMultiplier: 1.0,
              DogmaAttributes.fighterMissilesDurationMs: 3500.0,
            },
          ),
        },
      );
      expect(stats.dpsFighters, closeTo(12 * 36 / 3.5, 0.01));
      expect(
        stats.fighterSquadrons.single.activeAbility,
        FighterAbilityKind.missiles,
      );
    });

    test(
      'T2.19b Ametat shape uses attack; bomb is listed but inactive',
      () async {
        final stats = await run(
          fitting: fit(fighters: [sq(typeId: 40362)]),
          ship: carrierShip(heavy: 2, light: 0),
          modules: {
            '40362': fighterType(
              typeId: 40362,
              light: false,
              heavy: true,
              em: 253,
              thermal: 0,
              durationMs: 8000,
              effectIds: const [attackEffect, bombEffect, mjdEffect],
              extra: {
                DogmaAttributes.fighterBombTypeId: 41549.0,
                DogmaAttributes.fighterBombDurationMs: 60000.0,
              },
            ),
          },
        );
        expect(stats.dpsFighters, closeTo(6 * 253 / 8.0, 0.01));
        final row = stats.fighterSquadrons.single;
        expect(row.abilities, contains(FighterAbilityKind.bomb));
        expect(row.activeAbility, FighterAbilityKind.attack);
      },
    );

    test(
      'T2.20 Templar EM vs Einherji explosive land in the matching component',
      () async {
        final templar = await run(
          fitting: fit(fighters: [sq(typeId: 23055)]),
          modules: {'23055': fighterType(typeId: 23055, em: 97.5, thermal: 0)},
        );
        final einherji = await run(
          fitting: fit(fighters: [sq(typeId: 23057)]),
          modules: {
            '23057': fighterType(
              typeId: 23057,
              em: 0,
              thermal: 0,
              explosive: 169.5,
            ),
          },
        );
        expect(templar.dpsFighters, closeTo(6 * 97.5 / 5, 0.01));
        expect(einherji.dpsFighters, closeTo(6 * 169.5 / 5, 0.01));
      },
    );

    test(
      'T2.21 standup fighters classify but do not launch on a ship',
      () async {
        final stats = await run(
          fitting: fit(fighters: [sq(typeId: 999)]),
          modules: {
            '999': fighterType(typeId: 999, light: false, standup: true),
          },
        );
        expect(stats.fighterTubesUsed, 0);
        expect(stats.dpsFighters, 0);
      },
    );

    test(
      'T2.22 Thanatos-shaped hull with 3 light squadrons is 405 DPS, tubes 3/4, bay 18000/75000',
      () async {
        final stats = await run(
          ship: carrierShip(
            tubes: 4,
            light: 3,
            support: 0,
            heavy: 0,
            bay: 75000,
          ),
          fitting: fit(
            fighters: [sq(quantity: 6), sq(quantity: 6), sq(quantity: 6)],
          ),
          modules: {'23059': fighterType(thermal: 112.5, volume: 1000)},
        );
        expect(stats.dpsFighters, closeTo(405.0, 0.01));
        expect(stats.fighterTubesUsed, 3);
        expect(stats.fighterTubesMax, 4);
        expect(stats.fighterLightUsed, 3);
        expect(stats.fighterLightMax, 3);
        expect(stats.fighterBayUsed, closeTo(18000, 0.01));
        expect(stats.fighterBayMax, closeTo(75000, 0.01));
      },
    );

    test(
      'T2.22s Fighters V x Drone Interfacing V x hull V is x1.25 x1.5 x1.25',
      () async {
        final hull = carrierShip(
          extra: {
            182: capitalShips.toDouble(),
            183: gallenteCarrier.toDouble(),
            hullBonusAttr: 5.0,
          },
          effects: const [
            DogmaEffect(effectId: hullFighterEffect, name: 'hull'),
          ],
        );
        final stats = await run(
          ship: hull,
          fitting: fit(fighters: [sq(), sq(), sq()]),
          modules: {'23059': fighterType(thermal: 112.5)},
          skills: const [
            CharacterSkill(skillId: fightersSkill, level: 5),
            CharacterSkill(skillId: droneInterfacing, level: 5),
            CharacterSkill(skillId: gallenteCarrier, level: 5),
            CharacterSkill(skillId: capitalShips, level: 5),
          ],
          skillTypes: {
            fightersSkill: ModuleType(
              typeId: fightersSkill,
              name: 'Fighters',
              groupId: 255,
              groupName: 'Skill',
              slotType: SlotType.high,
              baseAttributes: {damageBonusAttr: 5.0},
              effects: const [DogmaEffect(effectId: fightersEffect, name: 'f')],
            ),
            droneInterfacing: ModuleType(
              typeId: droneInterfacing,
              name: 'Drone Interfacing',
              groupId: 255,
              groupName: 'Skill',
              slotType: SlotType.high,
              baseAttributes: {damageBonusAttr: 10.0},
              effects: const [
                DogmaEffect(effectId: interfacingEffect, name: 'di'),
              ],
            ),
            gallenteCarrier: ModuleType(
              typeId: gallenteCarrier,
              name: 'Gallente Carrier',
              groupId: 255,
              groupName: 'Skill',
              slotType: SlotType.high,
              baseAttributes: {DogmaAttributes.skillLevel: 1.0},
              effects: const [
                DogmaEffect(effectId: carrierScaleEffect, name: 'scale'),
              ],
            ),
          },
          modifiers: {
            fightersEffect: [
              EffectModifier(
                effectId: fightersEffect,
                func: 'OwnerRequiredSkillModifier',
                operator: 6,
                modifiedAttributeId: DogmaAttributes.fighterDamageMultiplier,
                modifyingAttributeId: damageBonusAttr,
                domain: 'charID',
                skillTypeId: fightersSkill,
              ),
            ],
            interfacingEffect: [
              EffectModifier(
                effectId: interfacingEffect,
                func: 'OwnerRequiredSkillModifier',
                operator: 6,
                modifiedAttributeId: DogmaAttributes.fighterDamageMultiplier,
                modifyingAttributeId: damageBonusAttr,
                domain: 'charID',
                skillTypeId: fightersSkill,
              ),
            ],
            hullFighterEffect: [
              EffectModifier(
                effectId: hullFighterEffect,
                func: 'OwnerRequiredSkillModifier',
                operator: 6,
                modifiedAttributeId: DogmaAttributes.fighterDamageMultiplier,
                modifyingAttributeId: hullBonusAttr,
                domain: 'charID',
                skillTypeId: fightersSkill,
              ),
            ],
            carrierScaleEffect: [
              EffectModifier(
                effectId: carrierScaleEffect,
                func: 'ItemModifier',
                operator: 0,
                modifiedAttributeId: hullBonusAttr,
                modifyingAttributeId: DogmaAttributes.skillLevel,
                domain: 'shipID',
              ),
            ],
          },
        );
        expect(stats.dpsFighters, closeTo(405.0 * 1.25 * 1.5 * 1.25, 0.01));
      },
    );

    test('T2.23 Nyx support cap 0 vs heavy cap 4', () async {
      final nyx = carrierShip(
        tubes: 5,
        light: 3,
        support: 0,
        heavy: 4,
        bay: 110000,
      );
      final support = await run(
        ship: nyx,
        fitting: fit(fighters: [sq(typeId: 40347, quantity: 3)]),
        modules: {
          '40347': fighterType(
            typeId: 40347,
            size: 3,
            light: false,
            support: true,
          ),
        },
      );
      expect(support.dpsFighters, 0);
      expect(support.fighterSupportUsed, 0);

      final heavy = await run(
        ship: nyx,
        fitting: fit(fighters: [sq(typeId: 32325)]),
        modules: {
          '32325': fighterType(typeId: 32325, light: false, heavy: true),
        },
      );
      expect(heavy.fighterHeavyUsed, 1);
      expect(heavy.dpsFighters, closeTo(248.4, 0.01));
    });

    test(
      'T2.25 Gallente Carrier III scales hull fighter bonus x1.15, not Capital Ships V',
      () async {
        final stats = await run(
          ship: carrierShip(
            extra: {
              182: capitalShips.toDouble(),
              183: gallenteCarrier.toDouble(),
              hullBonusAttr: 5.0,
            },
            effects: const [
              DogmaEffect(effectId: hullFighterEffect, name: 'hull'),
            ],
          ),
          modules: {'23059': fighterType()},
          skills: const [
            CharacterSkill(skillId: capitalShips, level: 5),
            CharacterSkill(skillId: gallenteCarrier, level: 3),
          ],
          skillTypes: {
            gallenteCarrier: ModuleType(
              typeId: gallenteCarrier,
              name: 'Gallente Carrier',
              groupId: 255,
              groupName: 'Skill',
              slotType: SlotType.high,
              baseAttributes: {DogmaAttributes.skillLevel: 1.0},
              effects: const [
                DogmaEffect(effectId: carrierScaleEffect, name: 'scale'),
              ],
            ),
          },
          modifiers: {
            hullFighterEffect: [
              EffectModifier(
                effectId: hullFighterEffect,
                func: 'OwnerRequiredSkillModifier',
                operator: 6,
                modifiedAttributeId: DogmaAttributes.fighterDamageMultiplier,
                modifyingAttributeId: hullBonusAttr,
                domain: 'charID',
                skillTypeId: fightersSkill,
              ),
            ],
            carrierScaleEffect: [
              EffectModifier(
                effectId: carrierScaleEffect,
                func: 'ItemModifier',
                operator: 0,
                modifiedAttributeId: hullBonusAttr,
                modifyingAttributeId: DogmaAttributes.skillLevel,
                domain: 'shipID',
              ),
            ],
          },
        );
        expect(stats.dpsFighters, closeTo(248.4 * 1.15, 0.01));
        expect(stats.dpsFighters, isNot(closeTo(248.4 * 1.25, 0.5)));
      },
    );

    test(
      'T2.26 role bonus not targeted by a required skill applies raw',
      () async {
        const roleAttr = 5983;
        final stats = await run(
          ship: carrierShip(
            extra: {roleAttr: 10.0},
            effects: const [DogmaEffect(effectId: 6984, name: 'role')],
          ),
          modules: {'23059': fighterType()},
          modifiers: {
            6984: [
              EffectModifier(
                effectId: 6984,
                func: 'OwnerRequiredSkillModifier',
                operator: 6,
                modifiedAttributeId: DogmaAttributes.fighterDamageMultiplier,
                modifyingAttributeId: roleAttr,
                domain: 'charID',
                skillTypeId: fightersSkill,
              ),
            ],
          },
        );
        expect(stats.dpsFighters, closeTo(248.4 * 1.10, 0.01));
      },
    );

    test(
      'T2.27 hull V + Fighters V + DDA compound x1.25 x1.25 x1.205',
      () async {
        final dda = ModuleType(
          typeId: 4405,
          name: 'DDA II',
          groupId: 646,
          groupName: 'DDA',
          slotType: SlotType.low,
          baseAttributes: {ddaBonusAttr: 20.5},
          effects: const [DogmaEffect(effectId: ddaEffect, name: 'dda')],
        );
        final stats = await run(
          ship: carrierShip(
            extra: {183: gallenteCarrier.toDouble(), hullBonusAttr: 5.0},
            effects: const [
              DogmaEffect(effectId: hullFighterEffect, name: 'hull'),
            ],
          ),
          fitting: fit(
            low: [
              const FittedModule(
                typeId: 4405,
                typeName: 'DDA II',
                slotType: SlotType.low,
                slotIndex: 0,
              ),
            ],
            fighters: [sq()],
          ),
          modules: {'23059': fighterType(), '4405': dda},
          skills: const [
            CharacterSkill(skillId: fightersSkill, level: 5),
            CharacterSkill(skillId: gallenteCarrier, level: 5),
          ],
          skillTypes: {
            fightersSkill: ModuleType(
              typeId: fightersSkill,
              name: 'Fighters',
              groupId: 255,
              groupName: 'Skill',
              slotType: SlotType.high,
              baseAttributes: {damageBonusAttr: 5.0},
              effects: const [DogmaEffect(effectId: fightersEffect, name: 'f')],
            ),
            gallenteCarrier: ModuleType(
              typeId: gallenteCarrier,
              name: 'Gallente Carrier',
              groupId: 255,
              groupName: 'Skill',
              slotType: SlotType.high,
              baseAttributes: {DogmaAttributes.skillLevel: 1.0},
              effects: const [
                DogmaEffect(effectId: carrierScaleEffect, name: 'scale'),
              ],
            ),
          },
          modifiers: {
            fightersEffect: [
              EffectModifier(
                effectId: fightersEffect,
                func: 'OwnerRequiredSkillModifier',
                operator: 6,
                modifiedAttributeId: DogmaAttributes.fighterDamageMultiplier,
                modifyingAttributeId: damageBonusAttr,
                domain: 'charID',
                skillTypeId: fightersSkill,
              ),
            ],
            hullFighterEffect: [
              EffectModifier(
                effectId: hullFighterEffect,
                func: 'OwnerRequiredSkillModifier',
                operator: 6,
                modifiedAttributeId: DogmaAttributes.fighterDamageMultiplier,
                modifyingAttributeId: hullBonusAttr,
                domain: 'charID',
                skillTypeId: fightersSkill,
              ),
            ],
            carrierScaleEffect: [
              EffectModifier(
                effectId: carrierScaleEffect,
                func: 'ItemModifier',
                operator: 0,
                modifiedAttributeId: hullBonusAttr,
                modifyingAttributeId: DogmaAttributes.skillLevel,
                domain: 'shipID',
              ),
            ],
            ddaEffect: [
              EffectModifier(
                effectId: ddaEffect,
                func: 'OwnerRequiredSkillModifier',
                operator: 6,
                modifiedAttributeId: DogmaAttributes.fighterDamageMultiplier,
                modifyingAttributeId: ddaBonusAttr,
                domain: 'charID',
                skillTypeId: fightersSkill,
              ),
            ],
          },
        );
        expect(stats.dpsFighters, closeTo(248.4 * 1.25 * 1.25 * 1.205, 0.01));
      },
    );

    test(
      'T2.28 Fighter Hangar Management V scales bay; hulls without 2055 stay 0',
      () async {
        final fhm = ModuleType(
          typeId: fhmSkill,
          name: 'Fighter Hangar Management',
          groupId: 255,
          groupName: 'Skill',
          slotType: SlotType.high,
          baseAttributes: {hangarBonusAttr: 5.0},
          effects: const [DogmaEffect(effectId: fhmEffect, name: 'fhm')],
        );
        final modifiers = {
          fhmEffect: [
            EffectModifier(
              effectId: fhmEffect,
              func: 'ItemModifier',
              operator: 6,
              modifiedAttributeId: DogmaAttributes.fighterCapacity,
              modifyingAttributeId: hangarBonusAttr,
              domain: 'shipID',
            ),
          ],
        };
        final trained = await run(
          modules: {'23059': fighterType()},
          skills: const [CharacterSkill(skillId: fhmSkill, level: 5)],
          skillTypes: {fhmSkill: fhm},
          modifiers: modifiers,
        );
        expect(trained.fighterBayMax, closeTo(75000 * 1.25, 0.01));

        final rifter = await run(
          ship: _rifter(),
          fitting: Fitting(
            id: 'r',
            name: 'Rifter',
            shipTypeId: 587,
            shipName: 'Rifter',
          ),
          modules: const {},
          skills: const [CharacterSkill(skillId: fhmSkill, level: 5)],
          skillTypes: {fhmSkill: fhm},
          modifiers: modifiers,
        );
        expect(rifter.fighterBayMax, 0);
      },
    );

    test(
      'T2.29 every bundled fighter type classifies and attack carriers have 2226/2233',
      () async {
        final dogma =
            json.decode(File('assets/sde/dogma.json').readAsStringSync())
                as Map<String, dynamic>;
        final fighterGroupIds = {
          for (final g
              in (dogma['groups'] as List).cast<Map<String, dynamic>>())
            if (g['categoryId'] == 87) g['groupId'] as int,
        };
        expect(fighterGroupIds, isNotEmpty);
        final fighters = (dogma['types'] as List)
            .cast<Map<String, dynamic>>()
            .where((t) => fighterGroupIds.contains(t['groupId'] as int))
            .toList();
        expect(fighters.length, greaterThanOrEqualTo(90));
        for (final raw in fighters) {
          final attrs = {
            for (final a
                in (raw['dogmaAttributes'] as List)
                    .cast<Map<String, dynamic>>())
              a['attributeId'] as int: (a['value'] as num).toDouble(),
          };
          expect(
            attrs.containsKey(DogmaAttributes.fighterSquadronMaxSize),
            isTrue,
            reason: '${raw['typeName']} must carry 2215',
          );
          final effectIds = [
            for (final e
                in (raw['dogmaEffects'] as List? ?? const [])
                    .cast<Map<String, dynamic>>())
              e['effectId'] as int,
          ];
          if (effectIds.contains(attackEffect)) {
            expect(
              attrs.containsKey(2226),
              isTrue,
              reason: '${raw['typeName']}',
            );
            expect(
              attrs.containsKey(2233),
              isTrue,
              reason: '${raw['typeName']}',
            );
          }
          final typeId = raw['typeId'] as int;
          final type = ModuleType(
            typeId: typeId,
            name: raw['typeName'] as String,
            groupId: raw['groupId'] as int,
            groupName: 'Fighter',
            slotType: SlotType.high,
            baseAttributes: attrs,
            effects: [
              for (final id in effectIds)
                DogmaEffect(effectId: id, name: 'e$id'),
            ],
          );
          final size = attrs[DogmaAttributes.fighterSquadronMaxSize]!.toInt();
          final stats = await run(
            fitting: fit(
              fighters: [
                FighterGroup(
                  typeId: typeId,
                  typeName: type.name,
                  quantity: size,
                ),
              ],
            ),
            modules: {typeId.toString(): type},
          );
          expect(
            stats.fighterSquadrons,
            isNotEmpty,
            reason: '${raw['typeName']} must classify as a fighter',
          );
        }
      },
    );
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
