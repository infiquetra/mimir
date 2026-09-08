import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/fitting/domain/dogma_attributes.dart';
import 'package:mimir/features/fitting/domain/dogma_engine.dart';
import 'package:mimir/features/fitting/domain/models.dart';

/// End-to-end proof that the bundled SDE data drives real weapon stats:
/// loads `assets/sde/dogma.json` and `assets/sde/effect_modifiers.json`
/// straight from disk (the same bytes the app bundles) and calculates the
/// DPS of a Rifter fitted with a real turret and ammo, using CCP's own
/// resolved racial-bonus modifiers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<int, Map<String, dynamic>> types;
  late Map<int, List<EffectModifier>> effectModifiers;

  setUpAll(() {
    final dogma =
        json.decode(File('assets/sde/dogma.json').readAsStringSync())
            as Map<String, dynamic>;
    types = {
      for (final t in (dogma['types'] as List).map(
        (t) => t as Map<String, dynamic>,
      ))
        t['typeId'] as int: t,
    };
    final modifiers =
        json.decode(File('assets/sde/effect_modifiers.json').readAsStringSync())
            as Map<String, dynamic>;
    effectModifiers = {
      for (final entry in modifiers.entries)
        int.parse(
          entry.key,
        ): ((entry.value as Map<String, dynamic>)['modifiers'] as List)
            .map(
              (m) => EffectModifier(
                effectId: int.parse(entry.key),
                func: (m as Map<String, dynamic>)['func'] as String,
                operator: m['operator'] as int,
                modifiedAttributeId: m['modifiedAttributeId'] as int,
                modifyingAttributeId: m['modifyingAttributeId'] as int?,
                domain: m['domain'] as String,
                skillTypeId: m['skillTypeId'] as int?,
                groupId: m['groupId'] as int?,
              ),
            )
            .toList(),
    };
  });

  Map<int, double> attributesOf(int typeId) => {
    for (final a in (types[typeId]!['dogmaAttributes'] as List).map(
      (a) => a as Map<String, dynamic>,
    ))
      a['attributeId'] as int: (a['value'] as num).toDouble(),
  };

  List<DogmaEffect> effectsOf(int typeId) => [
    for (final e in (types[typeId]!['dogmaEffects'] as List).map(
      (e) => e as Map<String, dynamic>,
    ))
      DogmaEffect(effectId: e['effectId'] as int, name: e['name'] as String),
  ];

  ModuleType moduleTypeOf(int typeId) {
    final raw = types[typeId]!;
    return ModuleType(
      typeId: typeId,
      name: raw['typeName'] as String,
      groupId: raw['groupId'] as int,
      groupName: '',
      slotType: SlotType.high,
      baseAttributes: attributesOf(typeId),
      effects: effectsOf(typeId),
    );
  }

  int typeIdNamed(String name) =>
      types.values.firstWhere((t) => t['typeName'] == name)['typeId'] as int;

  test(
    'Rifter racial bonuses and turret DPS come from bundled SDE data',
    () async {
      const rifter = 587;
      const minmatarFrigate = 3302;
      final turretId = typeIdNamed('125mm Gatling AutoCannon I');
      final ammoId = typeIdNamed('Proton S');

      final shipAttributes = attributesOf(rifter);
      final turretAttributes = attributesOf(turretId);
      final ammoAttributes = attributesOf(ammoId);

      // The bundled traits: per-level falloff and rate-of-fire values with
      // skill-linked modifiers on the ship's own effects.
      expect(shipAttributes[587], isNotNull);
      expect(shipAttributes[460], isNotNull);
      final shipEffectIds = effectsOf(rifter).map((e) => e.effectId).toSet();
      expect(
        effectModifiers.entries
            .where((e) => shipEffectIds.contains(e.key))
            .where((e) => e.value.any((m) => m.skillTypeId == minmatarFrigate))
            .length,
        2,
      );

      final fitting = Fitting(
        id: 'real',
        name: 'Real Rifter',
        shipTypeId: rifter,
        shipName: 'Rifter',
        highSlots: [
          FittedModule(
            typeId: turretId,
            typeName: '125mm Gatling AutoCannon I',
            slotType: SlotType.high,
            slotIndex: 0,
            chargeTypeId: ammoId,
            chargeName: 'Proton S',
          ),
        ],
      );
      final ship = ShipType(
        typeId: rifter,
        name: 'Rifter',
        description: '',
        groupId: 25,
        groupName: 'Frigate',
        baseAttributes: shipAttributes,
        effects: effectsOf(rifter),
      );

      final stats = await DogmaEngine().calculateStats(
        fitting,
        ship,
        {
          turretId.toString(): moduleTypeOf(turretId),
          ammoId.toString(): moduleTypeOf(ammoId),
        },
        const [CharacterSkill(skillId: minmatarFrigate, level: 5)],
        effectModifiers: effectModifiers,
      );

      // Independently recompute from the raw bundled attributes:
      // Minmatar Frigate V => rof * (1 - 7.5*5/100), falloff * (1 + 10*5/100).
      final expectedCycleMs =
          turretAttributes[DogmaAttributes.rateOfFire]! *
          (1 + (-7.5 * 5) / 100);
      final expectedVolley =
          DogmaAttributes.damageComponents
              .map((id) => ammoAttributes[id] ?? 0.0)
              .fold<double>(0, (a, b) => a + b) *
          turretAttributes[DogmaAttributes.turretDamageMultiplier]!;

      expect(stats.volley, closeTo(expectedVolley, 0.001));
      expect(
        stats.dpsGuns,
        closeTo(expectedVolley / (expectedCycleMs / 1000), 0.01),
      );
      expect(stats.dpsTotal, stats.dpsGuns);
      expect(
        stats.falloffRange,
        closeTo(turretAttributes[DogmaAttributes.falloff]! * 1.5, 0.001),
      );
      expect(
        stats.optimalRange,
        closeTo(turretAttributes[DogmaAttributes.optimalRange]!, 0.001),
      );

      // Sanity: a loaded autocannon Rifter deals real damage, and the bonus
      // actually shortened the cycle versus the untrained baseline.
      expect(stats.dpsGuns, greaterThan(0));
      final untrained = await DogmaEngine().calculateStats(
        fitting,
        ship,
        {
          turretId.toString(): moduleTypeOf(turretId),
          ammoId.toString(): moduleTypeOf(ammoId),
        },
        const [],
        effectModifiers: effectModifiers,
      );
      expect(stats.dpsGuns, greaterThan(untrained.dpsGuns));
    },
  );
}
