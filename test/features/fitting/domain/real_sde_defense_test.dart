import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/fitting/domain/cap_simulator.dart';
import 'package:mimir/features/fitting/domain/dogma_attributes.dart';
import 'package:mimir/features/fitting/domain/dogma_engine.dart';
import 'package:mimir/features/fitting/domain/models.dart';

/// Bundled-SDE defense parity (design §7.3 T8.1–T8.3).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<int, Map<String, dynamic>> types;
  late Map<int, List<EffectModifier>> effectModifiers;
  late List<int> skillTypeIds;

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

    final skillsJson =
        json.decode(File('assets/sde/skills.json').readAsStringSync())
            as Map<String, dynamic>;
    final skillGroupIds = {
      for (final g
          in (skillsJson['groups'] as List).cast<Map<String, dynamic>>())
        if (g['categoryId'] == 16) g['groupId'] as int,
    };
    skillTypeIds = [
      for (final t
          in (skillsJson['types'] as List).cast<Map<String, dynamic>>())
        if (skillGroupIds.contains(t['groupId'] as int)) t['typeId'] as int,
    ];
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

  ShipType shipTypeOf(int typeId) {
    final raw = types[typeId]!;
    return ShipType(
      typeId: typeId,
      name: raw['typeName'] as String,
      description: '',
      groupId: raw['groupId'] as int,
      groupName: '',
      baseAttributes: attributesOf(typeId),
      effects: effectsOf(typeId),
    );
  }

  Map<int, ModuleType> allSkillTypes() => {
    for (final id in skillTypeIds)
      if (types.containsKey(id)) id: moduleTypeOf(id),
  };

  List<CharacterSkill> allV() => [
    for (final id in allSkillTypes().keys)
      CharacterSkill(skillId: id, level: 5),
  ];

  double omniEhp(double hp, double em, double th, double kin, double exp) {
    final meanResist = ((1 - em) + (1 - th) + (1 - kin) + (1 - exp)) / 4;
    return hp / (1 - meanResist);
  }

  test('T8.1 bare Rifter totalEhp matches raw-resonance recompute', () async {
    const rifter = 587;
    final attrs = attributesOf(rifter);
    final expectedHull =
        attrs[DogmaAttributes.hullHp]! / attrs[DogmaAttributes.hullEmResist]!;
    final expectedShield = omniEhp(
      attrs[DogmaAttributes.shieldCapacity]!,
      attrs[DogmaAttributes.shieldEmResist]!,
      attrs[DogmaAttributes.shieldThermalResist]!,
      attrs[DogmaAttributes.shieldKineticResist]!,
      attrs[DogmaAttributes.shieldExplosiveResist]!,
    );
    final expectedArmor = omniEhp(
      attrs[DogmaAttributes.armorHp]!,
      attrs[DogmaAttributes.armorEmResist]!,
      attrs[DogmaAttributes.armorThermalResist]!,
      attrs[DogmaAttributes.armorKineticResist]!,
      attrs[DogmaAttributes.armorExplosiveResist]!,
    );
    final expectedTotal = expectedHull + expectedShield + expectedArmor;

    final stats = await DogmaEngine().calculateStats(
      const Fitting(
        id: 'bare',
        name: 'Rifter',
        shipTypeId: rifter,
        shipName: 'Rifter',
      ),
      shipTypeOf(rifter),
      const {},
      const [],
    );

    expect(stats.defenses.hullEhp, closeTo(expectedHull, 0.01));
    expect(stats.defenses.totalEhp, closeTo(expectedTotal, 0.01));
    expect(stats.defenses.totalEhp, closeTo(1809.744, 0.01));
  });

  test(
    'T8.1b Rifter + MSE II + Shield Management V is 1937.5 shield HP',
    () async {
      const rifter = 587;
      const mse = 3831;
      const shieldManagement = 3419;
      final stats = await DogmaEngine().calculateStats(
        const Fitting(
          id: 'mse',
          name: 'Rifter MSE',
          shipTypeId: rifter,
          shipName: 'Rifter',
          medSlots: [
            FittedModule(
              typeId: mse,
              typeName: 'Medium Shield Extender II',
              slotType: SlotType.med,
              slotIndex: 0,
            ),
          ],
        ),
        shipTypeOf(rifter),
        {mse.toString(): moduleTypeOf(mse)},
        const [CharacterSkill(skillId: shieldManagement, level: 5)],
        effectModifiers: effectModifiers,
      );

      expect(stats.defenses.shieldHp, closeTo(1937.5, 0.01));
    },
  );

  test('T8.2 Rifter + DCU II hull EM resist is 59.8%', () async {
    const rifter = 587;
    const dcu = 2048;
    final stats = await DogmaEngine().calculateStats(
      const Fitting(
        id: 'dcu',
        name: 'Rifter DCU',
        shipTypeId: rifter,
        shipName: 'Rifter',
        lowSlots: [
          FittedModule(
            typeId: dcu,
            typeName: 'Damage Control II',
            slotType: SlotType.low,
            slotIndex: 0,
          ),
        ],
      ),
      shipTypeOf(rifter),
      {dcu.toString(): moduleTypeOf(dcu)},
      const [],
      effectModifiers: effectModifiers,
    );

    expect(stats.defenses.hullResists.em, closeTo(59.8, 0.01));
  });

  test(
    'T8.3 Myrmidon + LAR II + LSE II All V: 112.444 HP/s and (3500+2600)*1.25 shield',
    () async {
      const myrmidon = 24700;
      const lar = 3540;
      const lse = 3841;
      final skillTypes = allSkillTypes();
      final stats = await DogmaEngine().calculateStats(
        const Fitting(
          id: 'myrm',
          name: 'Myrmidon tank',
          shipTypeId: myrmidon,
          shipName: 'Myrmidon',
          lowSlots: [
            FittedModule(
              typeId: lar,
              typeName: 'Large Armor Repairer II',
              slotType: SlotType.low,
              slotIndex: 0,
            ),
          ],
          medSlots: [
            FittedModule(
              typeId: lse,
              typeName: 'Large Shield Extender II',
              slotType: SlotType.med,
              slotIndex: 0,
            ),
          ],
        ),
        shipTypeOf(myrmidon),
        {lar.toString(): moduleTypeOf(lar), lse.toString(): moduleTypeOf(lse)},
        allV(),
        effectModifiers: effectModifiers,
        skillTypes: skillTypes,
      );

      expect(stats.defenses.effectiveArmorRepair, closeTo(112.444, 0.01));
      expect(stats.defenses.shieldHp, closeTo((3500 + 2600) * 1.25, 0.01));

      final cap = CapSimulator(
        capacity: stats.capacitorCapacity,
        rechargeMs: stats.capacitorRecharge,
        drains: const [CapDrain(durationMs: 11250, capNeed: 400)],
      ).run();
      expect(stats.isCapStable, cap.isStable);
    },
  );
}
