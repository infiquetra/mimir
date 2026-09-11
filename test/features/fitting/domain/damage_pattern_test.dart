import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/fitting/domain/damage_pattern.dart';
import 'package:mimir/features/fitting/domain/dogma_attributes.dart';
import 'package:mimir/features/fitting/domain/dogma_engine.dart';
import 'package:mimir/features/fitting/domain/models.dart';

void main() {
  group('DamagePattern ehpAgainst', () {
    const hole = ResistProfile(em: 0, thermal: 50, kinetic: 50, explosive: 50);
    const skew = ResistProfile(em: 0, thermal: 20, kinetic: 40, explosive: 50);
    const profile = DefenseProfile(armorHp: 1000, armorResists: hole);

    test('T3.1 pure EM against 0/50/50/50 is raw HP 1000', () {
      const pattern = DamagePattern(
        em: 1,
        thermal: 0,
        kinetic: 0,
        explosive: 0,
      );
      expect(profile.ehpAgainst(pattern).armor, closeTo(1000, 0.01));
    });

    test('T3.2 pure explosive against 0/50/50/50 is 2000', () {
      const pattern = DamagePattern(
        em: 0,
        thermal: 0,
        kinetic: 0,
        explosive: 1,
      );
      expect(profile.ehpAgainst(pattern).armor, closeTo(2000, 0.01));
    });

    test('T3.3 omni against 0/50/50/50 is 1600 and matches 1-mean', () {
      final ehp = profile.ehpAgainst(DamagePattern.omni).armor;
      expect(ehp, closeTo(1600, 0.01));
      final omniResist = hole.omniResist;
      expect(ehp, closeTo(1000 / (1 - omniResist / 100), 1e-9));
    });

    test('T3.4 realistic skew 3/19/78 EM/Th/Kin is 1538.46', () {
      final pattern = DamagePattern.fromAmounts(
        em: 3,
        thermal: 19,
        kinetic: 78,
        explosive: 0,
      );
      expect(pattern, isNotNull);
      const skewed = DefenseProfile(armorHp: 1000, armorResists: skew);
      expect(skewed.ehpAgainst(pattern!).armor, closeTo(1538.4615, 0.001));
    });

    test('T3.5 zero resists equal raw HP for any pattern', () {
      const raw = DefenseProfile(armorHp: 1000, armorResists: ResistProfile());
      expect(raw.ehpAgainst(DamagePattern.omni).armor, 1000);
      expect(
        raw
            .ehpAgainst(
              const DamagePattern(em: 1, thermal: 0, kinetic: 0, explosive: 0),
            )
            .armor,
        1000,
      );
    });

    test(
      'T3.6 omni and fromAmounts labels; LayeredEhp carries the pattern',
      () {
        expect(DamagePattern.omni.label, 'omni');
        final observed = DamagePattern.fromAmounts(
          em: 3,
          thermal: 19,
          kinetic: 78,
          explosive: 0,
        );
        expect(observed, isNotNull);
        expect(observed!.label, 'observed');
        const defense = DefenseProfile(armorHp: 1000, armorResists: hole);
        final layered = defense.ehpAgainst(observed);
        expect(identical(layered.pattern, observed), isTrue);
        expect(layered.pattern.label, 'observed');
      },
    );

    test('C.7 fromAmounts all zero returns null', () {
      expect(
        DamagePattern.fromAmounts(em: 0, thermal: 0, kinetic: 0, explosive: 0),
        isNull,
      );
    });

    test(
      'C.8 100% resist on a layer returns raw HP, never infinity or NaN',
      () {
        const immune = DefenseProfile(
          armorHp: 1000,
          armorResists: ResistProfile(
            em: 100,
            thermal: 100,
            kinetic: 100,
            explosive: 100,
          ),
        );
        final ehp = immune.ehpAgainst(DamagePattern.omni).armor;
        expect(ehp, 1000);
        expect(ehp.isFinite, isTrue);
        expect(ehp.isNaN, isFalse);
      },
    );
  });

  group('DamagePattern engine parity', () {
    test(
      'C.9 Rifter+DCU totalEhp equals ehpAgainst(omni).total within 1e-9',
      () async {
        const hullEm = 113;
        const hullThermal = 110;
        const hullKinetic = 109;
        const hullExplosive = 111;
        final ship = ShipType(
          typeId: 587,
          name: 'Rifter',
          description: '',
          groupId: 25,
          groupName: 'Frigate',
          baseAttributes: {
            DogmaAttributes.cpuOutput: 125,
            DogmaAttributes.powerOutput: 37,
            DogmaAttributes.shieldCapacity: 450,
            DogmaAttributes.armorHp: 450,
            DogmaAttributes.hullHp: 350,
            DogmaAttributes.shieldEmResist: 1.0,
            DogmaAttributes.shieldThermalResist: 0.8,
            DogmaAttributes.shieldKineticResist: 0.6,
            DogmaAttributes.shieldExplosiveResist: 0.5,
            DogmaAttributes.armorEmResist: 0.4,
            DogmaAttributes.armorThermalResist: 0.65,
            DogmaAttributes.armorKineticResist: 0.75,
            DogmaAttributes.armorExplosiveResist: 0.9,
            hullEm: 0.67,
            hullThermal: 0.67,
            hullKinetic: 0.67,
            hullExplosive: 0.67,
            974: 1.0,
            975: 1.0,
            976: 1.0,
            977: 1.0,
          },
        );
        const dcu = ModuleType(
          typeId: 2048,
          name: 'Damage Control II',
          groupId: 60,
          groupName: 'Damage Control',
          slotType: SlotType.low,
          baseAttributes: {
            271: 0.875,
            272: 0.875,
            273: 0.875,
            274: 0.875,
            267: 0.85,
            268: 0.85,
            269: 0.85,
            270: 0.85,
            974: 0.6,
            975: 0.6,
            976: 0.6,
            977: 0.6,
          },
          effects: [DogmaEffect(effectId: 2302, name: 'damageControl')],
        );
        const dcuModifiers = {
          2302: [
            EffectModifier(
              effectId: 2302,
              func: 'ItemModifier',
              operator: 0,
              modifiedAttributeId: 267,
              modifyingAttributeId: 267,
            ),
            EffectModifier(
              effectId: 2302,
              func: 'ItemModifier',
              operator: 0,
              modifiedAttributeId: 268,
              modifyingAttributeId: 268,
            ),
            EffectModifier(
              effectId: 2302,
              func: 'ItemModifier',
              operator: 0,
              modifiedAttributeId: 269,
              modifyingAttributeId: 269,
            ),
            EffectModifier(
              effectId: 2302,
              func: 'ItemModifier',
              operator: 0,
              modifiedAttributeId: 270,
              modifyingAttributeId: 270,
            ),
            EffectModifier(
              effectId: 2302,
              func: 'ItemModifier',
              operator: 0,
              modifiedAttributeId: 113,
              modifyingAttributeId: 974,
            ),
            EffectModifier(
              effectId: 2302,
              func: 'ItemModifier',
              operator: 0,
              modifiedAttributeId: 111,
              modifyingAttributeId: 975,
            ),
            EffectModifier(
              effectId: 2302,
              func: 'ItemModifier',
              operator: 0,
              modifiedAttributeId: 109,
              modifyingAttributeId: 976,
            ),
            EffectModifier(
              effectId: 2302,
              func: 'ItemModifier',
              operator: 0,
              modifiedAttributeId: 110,
              modifyingAttributeId: 977,
            ),
            EffectModifier(
              effectId: 2302,
              func: 'ItemModifier',
              operator: 0,
              modifiedAttributeId: 271,
              modifyingAttributeId: 271,
            ),
            EffectModifier(
              effectId: 2302,
              func: 'ItemModifier',
              operator: 0,
              modifiedAttributeId: 272,
              modifyingAttributeId: 272,
            ),
            EffectModifier(
              effectId: 2302,
              func: 'ItemModifier',
              operator: 0,
              modifiedAttributeId: 273,
              modifyingAttributeId: 273,
            ),
            EffectModifier(
              effectId: 2302,
              func: 'ItemModifier',
              operator: 0,
              modifiedAttributeId: 274,
              modifyingAttributeId: 274,
            ),
          ],
        };
        final stats = await DogmaEngine().calculateStats(
          const Fitting(
            id: 'dcu',
            name: 'Rifter DCU',
            shipTypeId: 587,
            shipName: 'Rifter',
            lowSlots: [
              FittedModule(
                typeId: 2048,
                typeName: 'Damage Control II',
                slotType: SlotType.low,
                slotIndex: 0,
              ),
            ],
          ),
          ship,
          {'2048': dcu},
          const [],
          effectModifiers: dcuModifiers,
        );

        expect(
          stats.defenses.totalEhp,
          closeTo(stats.defenses.ehpAgainst(DamagePattern.omni).total, 1e-9),
        );
      },
    );
  });
}
