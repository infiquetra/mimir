import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/fitting/domain/dogma_attributes.dart';
import 'package:mimir/features/fitting/domain/dogma_engine.dart';
import 'package:mimir/features/fitting/domain/models.dart';

/// Rifter with real base resonances from the bundled SDE:
/// shield 1.0/0.5/0.6/0.8, armor 0.4/0.9/0.75/0.65, hull 1.0 x4.
ShipType rifter() => ShipType(
  typeId: 587,
  name: 'Rifter',
  description: 'A Minmatar frigate',
  groupId: 25,
  groupName: 'Frigate',
  baseAttributes: {
    DogmaAttributes.cpuOutput: 125.0,
    DogmaAttributes.powerOutput: 37.0,
    DogmaAttributes.maxVelocity: 365.0,
    DogmaAttributes.shieldCapacity: 400.0,
    DogmaAttributes.armorHp: 400.0,
    DogmaAttributes.hullHp: 350.0,
    DogmaAttributes.shieldEmResist: 1.0,
    DogmaAttributes.shieldThermalResist: 0.5,
    DogmaAttributes.shieldKineticResist: 0.6,
    DogmaAttributes.shieldExplosiveResist: 0.8,
    DogmaAttributes.armorEmResist: 0.4,
    DogmaAttributes.armorThermalResist: 0.9,
    DogmaAttributes.armorKineticResist: 0.75,
    DogmaAttributes.armorExplosiveResist: 0.65,
    DogmaAttributes.hullEmResist: 1.0,
    DogmaAttributes.hullThermalResist: 1.0,
    DogmaAttributes.hullKineticResist: 1.0,
    DogmaAttributes.hullExplosiveResist: 1.0,
  },
);

Fitting fittingWith(ModuleType module) => Fitting(
  id: '1',
  name: 'Rifter with module',
  shipTypeId: 587,
  shipName: 'Rifter',
  medSlots: [
    FittedModule(
      typeId: module.typeId,
      typeName: module.name,
      slotType: SlotType.med,
      slotIndex: 0,
      state: ModuleState.online,
    ),
  ],
);

void main() {
  final engine = DogmaEngine();

  group('DogmaEngine effect modifiers', () {
    test(
      'postPercent (operator 6) applies hardener bonuses to resonances',
      () async {
        // EM Shield Hardener II: effect 5230 modifies ship shield resonances
        // 271-274 from module attributes 984-987 (-55 for EM).
        const hardener = ModuleType(
          typeId: 2301,
          name: 'EM Shield Hardener II',
          groupId: 77,
          groupName: 'Shield Hardeners',
          slotType: SlotType.med,
          baseAttributes: {984: -55.0, 985: 0.0, 986: 0.0, 987: 0.0},
          effects: [
            DogmaEffect(
              effectId: 5230,
              name: 'modifyActiveShieldResonancePostPercent',
            ),
          ],
        );
        const modifiers = {
          5230: [
            EffectModifier(
              effectId: 5230,
              func: 'ItemModifier',
              operator: 6,
              modifiedAttributeId: DogmaAttributes.shieldEmResist,
              modifyingAttributeId: 984,
            ),
          ],
        };

        final stats = await engine.calculateStats(
          fittingWith(hardener),
          rifter(),
          {'2301': hardener},
          [],
          effectModifiers: modifiers,
        );

        // resonance 1.0 * (1 - 55/100) = 0.45 -> 55% resist
        expect(stats.defenses.shieldResists.em, closeTo(55.0, 0.001));
        // untouched resonances keep base values
        expect(stats.defenses.shieldResists.thermal, closeTo(50.0, 0.001));
      },
    );

    test('postMul (operator 0) applies Damage Control resonances', () async {
      // Damage Control II: effect 2302 multiplies ship armor resonances by
      // the module's own resonance attributes (0.85).
      const damageControl = ModuleType(
        typeId: 2048,
        name: 'Damage Control II',
        groupId: 62,
        groupName: 'Damage Control',
        slotType: SlotType.low,
        baseAttributes: {267: 0.85, 268: 0.85, 269: 0.85, 270: 0.85},
        effects: [DogmaEffect(effectId: 2302, name: 'damageControl')],
      );
      const modifiers = {
        2302: [
          EffectModifier(
            effectId: 2302,
            func: 'ItemModifier',
            operator: 0,
            modifiedAttributeId: DogmaAttributes.armorEmResist,
            modifyingAttributeId: 267,
          ),
        ],
      };

      final fitting = Fitting(
        id: '1',
        name: 'Rifter with DC',
        shipTypeId: 587,
        shipName: 'Rifter',
        lowSlots: [
          FittedModule(
            typeId: 2048,
            typeName: 'Damage Control II',
            slotType: SlotType.low,
            slotIndex: 0,
            state: ModuleState.online,
          ),
        ],
      );

      final stats = await engine.calculateStats(
        fitting,
        rifter(),
        {'2048': damageControl},
        [],
        effectModifiers: modifiers,
      );

      // resonance 0.4 * 0.85 = 0.34 -> 66% resist
      expect(stats.defenses.armorResists.em, closeTo(66.0, 0.001));
    });

    test(
      'stacked postPercent modifiers take the dogma stacking penalty',
      () async {
        const hardener = ModuleType(
          typeId: 2301,
          name: 'Hardener',
          groupId: 77,
          groupName: 'Shield Hardeners',
          slotType: SlotType.med,
          baseAttributes: {984: -55.0},
          effects: [DogmaEffect(effectId: 100, name: 'a')],
        );
        // Two modifiers on the same non-stackable resonance: -55 and -50.
        const modifiers = {
          100: [
            EffectModifier(
              effectId: 100,
              func: 'ItemModifier',
              operator: 6,
              modifiedAttributeId: DogmaAttributes.shieldEmResist,
              modifyingAttributeId: 984,
            ),
          ],
          101: [
            EffectModifier(
              effectId: 101,
              func: 'ItemModifier',
              operator: 6,
              modifiedAttributeId: DogmaAttributes.shieldEmResist,
              modifyingAttributeId: 984,
            ),
          ],
        };
        // Second module instance supplies the -50 via its own attribute map.
        const second = ModuleType(
          typeId: 2302,
          name: 'Second hardener',
          groupId: 77,
          groupName: 'Shield Hardeners',
          slotType: SlotType.med,
          baseAttributes: {984: -50.0},
          effects: [DogmaEffect(effectId: 101, name: 'b')],
        );
        final fitting = Fitting(
          id: '1',
          name: 'Stacked',
          shipTypeId: 587,
          shipName: 'Rifter',
          medSlots: [
            FittedModule(
              typeId: 2301,
              typeName: 'Hardener',
              slotType: SlotType.med,
              slotIndex: 0,
              state: ModuleState.online,
            ),
            FittedModule(
              typeId: 2302,
              typeName: 'Second hardener',
              slotType: SlotType.med,
              slotIndex: 1,
              state: ModuleState.online,
            ),
          ],
        );

        final stats = await engine.calculateStats(
          fitting,
          rifter(),
          {'2301': hardener, '2302': second},
          [],
          effectModifiers: modifiers,
        );

        // (1 - 0.55) * (1 - 0.50 * penalty2) with penalty2 = 0.869...
        final expected =
            (1 - (1 - 0.55) * (1 - 0.50 * DogmaEngine.getStackingPenalty(2))) *
            100;
        expect(stats.defenses.shieldResists.em, closeTo(expected, 0.001));
        expect(stats.defenses.shieldResists.em, greaterThan(55.0));
        expect(
          stats.defenses.shieldResists.em,
          lessThan(100.0 - 0.45 * 0.50 * 100),
        );
      },
    );

    test(
      'without modifiers (offline) base resists are reported unchanged',
      () async {
        const hardener = ModuleType(
          typeId: 2301,
          name: 'EM Shield Hardener II',
          groupId: 77,
          groupName: 'Shield Hardeners',
          slotType: SlotType.med,
          baseAttributes: {984: -55.0},
          effects: [DogmaEffect(effectId: 5230, name: 'harden')],
        );

        final stats = await engine.calculateStats(
          fittingWith(hardener),
          rifter(),
          {'2301': hardener},
          [],
        );

        expect(stats.defenses.shieldResists.em, closeTo(0.0, 0.001));
      },
    );

    test('itemID-domain modifiers do not touch ship attributes', () async {
      const module = ModuleType(
        typeId: 438,
        name: '1MN Afterburner II',
        groupId: 46,
        groupName: 'Propulsion',
        slotType: SlotType.med,
        baseAttributes: {20: 135.0, 1223: 10.0},
        effects: [DogmaEffect(effectId: 3175, name: 'overloadSelfSpeedBonus')],
      );
      const modifiers = {
        3175: [
          EffectModifier(
            effectId: 3175,
            func: 'ItemModifier',
            operator: 6,
            modifiedAttributeId: 20,
            modifyingAttributeId: 1223,
            domain: 'itemID',
          ),
        ],
      };

      final stats = await engine.calculateStats(
        fittingWith(module),
        rifter(),
        {'438': module},
        [],
        effectModifiers: modifiers,
      );

      expect(stats.maxVelocity, closeTo(365.0, 0.001));
    });
  });
}
