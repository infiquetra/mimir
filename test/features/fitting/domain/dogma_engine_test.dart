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
