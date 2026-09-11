import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_fit_deriver.dart';
import 'package:mimir/features/combat_analyzer/domain/tank_classifier.dart';
import 'package:mimir/features/fitting/data/fitting_stats_inputs.dart';
import 'package:mimir/features/fitting/domain/dogma_attributes.dart';
import 'package:mimir/features/fitting/domain/dogma_engine.dart';
import 'package:mimir/features/fitting/domain/models.dart';

void main() {
  group('CombatFitDeriver', () {
    const mseEffect = 21;
    const mseSigEffect = 2029;
    const ac = 2889;
    const ammo = 178;
    const mse = 3831;
    const saar = 33076;

    ShipType rifter({int highs = 4, int meds = 3, int lows = 3}) => ShipType(
      typeId: 587,
      name: 'Rifter',
      description: 'A Minmatar frigate',
      groupId: 25,
      groupName: 'Frigate',
      highSlots: highs,
      medSlots: meds,
      lowSlots: lows,
      rigSlots: 3,
      baseAttributes: {
        DogmaAttributes.cpuOutput: 125.0,
        DogmaAttributes.powerOutput: 37.0,
        DogmaAttributes.maxVelocity: 365.0,
        DogmaAttributes.mass: 1067000.0,
        DogmaAttributes.inertiaModifier: 3.2,
        DogmaAttributes.signatureRadius: 35.0,
        DogmaAttributes.shieldCapacity: 450.0,
        DogmaAttributes.armorHp: 450.0,
        DogmaAttributes.hullHp: 350.0,
        DogmaAttributes.shieldRechargeTime: 625000.0,
        DogmaAttributes.capacitorCapacity: 250.0,
        DogmaAttributes.capacitorRechargeTime: 125000.0,
        DogmaAttributes.shieldEmResist: 1.0,
        DogmaAttributes.shieldThermalResist: 0.8,
        DogmaAttributes.shieldKineticResist: 0.6,
        DogmaAttributes.shieldExplosiveResist: 0.5,
        DogmaAttributes.armorEmResist: 0.4,
        DogmaAttributes.armorThermalResist: 0.65,
        DogmaAttributes.armorKineticResist: 0.75,
        DogmaAttributes.armorExplosiveResist: 0.9,
        DogmaAttributes.hullEmResist: 0.67,
        DogmaAttributes.hullThermalResist: 0.67,
        DogmaAttributes.hullKineticResist: 0.67,
        DogmaAttributes.hullExplosiveResist: 0.67,
      },
    );

    ModuleType autocannon() => const ModuleType(
      typeId: ac,
      name: '200mm AutoCannon II',
      groupId: 55,
      groupName: 'Projectile Weapon',
      slotType: SlotType.high,
      baseAttributes: {
        DogmaAttributes.turretDamageMultiplier: 2.0,
        DogmaAttributes.rateOfFire: 4000.0,
      },
    );

    ModuleType fusion() => const ModuleType(
      typeId: ammo,
      name: 'Republic Fusion S',
      groupId: 83,
      groupName: 'Projectile Ammo',
      slotType: SlotType.high,
      baseAttributes: {DogmaAttributes.explosiveDamage: 12.0},
    );

    ModuleType mseII() => const ModuleType(
      typeId: mse,
      name: 'Medium Shield Extender II',
      groupId: 38,
      groupName: 'Shield Extender',
      slotType: SlotType.med,
      baseAttributes: {72: 1100.0, 983: 7.0},
      effects: [
        DogmaEffect(effectId: mseEffect, name: 'shieldCapacityBonusOnline'),
        DogmaEffect(effectId: mseSigEffect, name: 'addToSignatureRadius2'),
      ],
    );

    ModuleType saarModule() => const ModuleType(
      typeId: saar,
      name: 'Small Ancillary Armor Repairer',
      groupId: 1199,
      groupName: 'Ancillary Armor Repairer',
      slotType: SlotType.low,
      baseAttributes: {84: 52.0, 1886: 3.0, DogmaAttributes.duration: 6000.0},
      effects: [DogmaEffect(effectId: 5275, name: 'fueledArmorRepair')],
    );

    Map<int, List<EffectModifier>> mseModifiers() => const {
      mseEffect: [
        EffectModifier(
          effectId: mseEffect,
          func: 'ItemModifier',
          operator: 2,
          modifiedAttributeId: DogmaAttributes.shieldCapacity,
          modifyingAttributeId: 72,
          domain: 'shipID',
        ),
      ],
      mseSigEffect: [
        EffectModifier(
          effectId: mseSigEffect,
          func: 'ItemModifier',
          operator: 2,
          modifiedAttributeId: DogmaAttributes.signatureRadius,
          modifyingAttributeId: 983,
          domain: 'shipID',
        ),
      ],
    };

    Fitting armedFit({int mysteryTypeId = 0}) => Fitting(
      id: 'aar-fit',
      name: 'Rifter PvP',
      shipTypeId: 587,
      shipName: 'Rifter',
      highSlots: [
        for (var i = 0; i < 3; i++)
          FittedModule(
            typeId: mysteryTypeId == 0 ? ac : mysteryTypeId,
            typeName: mysteryTypeId == 0
                ? '200mm AutoCannon II'
                : 'Mystery Gun',
            slotType: SlotType.high,
            slotIndex: i,
            chargeTypeId: ammo,
            chargeName: 'Republic Fusion S',
          ),
      ],
      medSlots: const [
        FittedModule(
          typeId: mse,
          typeName: 'Medium Shield Extender II',
          slotType: SlotType.med,
          slotIndex: 0,
        ),
      ],
    );

    FittingStatsInputs inputsFor(
      Fitting fitting, {
      Map<int, String> unresolved = const {},
      ShipType? ship,
    }) {
      final shipType = ship ?? rifter();
      return FittingStatsInputs(
        shipType: shipType,
        moduleTypes: {
          '$ac': autocannon(),
          '$ammo': fusion(),
          '$mse': mseII(),
          '$saar': saarModule(),
        },
        skillTypes: const {},
        effectModifiers: mseModifiers(),
        unresolved: unresolved,
      );
    }

    FitEvidence evidenceOf(Fitting fitting) => FitEvidence(
      role: FitEvidenceRole.pilot,
      source: EvidenceSource.manualFitImport,
      confidence: EvidenceConfidence.confirmed,
      fitting: fitting,
    );

    const allFive = AarSkillContext(basis: AarSkillBasis.allFive, skills: []);

    test(
      'T1.1 Rifter + 3x AC + MSE II derives EHP, gun DPS and capacitor',
      () async {
        final derivation = await const CombatFitDeriver().derive(
          evidence: evidenceOf(armedFit()),
          subject: AarFitSubject.self,
          inputs: inputsFor(armedFit()),
          skills: allFive,
        );
        expect(derivation.stats.defenses.totalEhp, greaterThan(0));
        expect(derivation.stats.dpsGuns, greaterThan(0));
        expect(derivation.stats.capacitorCapacity, greaterThan(0));
      },
    );

    test('T1.2 derivation stats equal a direct DogmaEngine call', () async {
      final fitting = armedFit();
      final inputs = inputsFor(fitting);
      final engineStats = await DogmaEngine().calculateStats(
        fitting,
        inputs.shipType,
        inputs.moduleTypes,
        allFive.skills,
        effectModifiers: inputs.effectModifiers,
        skillTypes: inputs.skillTypes,
      );
      final derivation = await const CombatFitDeriver().derive(
        evidence: evidenceOf(fitting),
        subject: AarFitSubject.self,
        inputs: inputs,
        skills: allFive,
      );
      expect(derivation.stats, engineStats);
    });

    test('T1.4 hull-only stats equal baseline and tank is unfitted', () async {
      const hull = Fitting(
        id: 'hull',
        name: 'Empty Rifter',
        shipTypeId: 587,
        shipName: 'Rifter',
      );
      final derivation = await const CombatFitDeriver().derive(
        evidence: evidenceOf(hull),
        subject: AarFitSubject.self,
        inputs: inputsFor(hull),
        skills: allFive,
      );
      expect(derivation.stats, derivation.baseline);
      expect(derivation.tank.mode, TankMode.unfitted);
    });

    test('T1.5 coverage describe contains Mid 1/3 and Low 0/3', () async {
      final ship = rifter(highs: 3, meds: 3, lows: 3);
      final fitting = armedFit();
      final derivation = await const CombatFitDeriver().derive(
        evidence: evidenceOf(fitting),
        subject: AarFitSubject.self,
        inputs: inputsFor(fitting, ship: ship),
        skills: allFive,
      );
      expect(derivation.coverage.describe(), contains('Mid 1/3'));
      expect(derivation.coverage.describe(), contains('Low 0/3'));
    });

    test('T1.6 unresolved module is a floor, not a throw', () async {
      const missing = 99999;
      final fitting = armedFit(mysteryTypeId: missing);
      final derivation = await const CombatFitDeriver().derive(
        evidence: evidenceOf(fitting),
        subject: AarFitSubject.self,
        inputs: inputsFor(fitting, unresolved: {missing: 'Mystery Gun'}),
        skills: allFive,
      );
      expect(derivation.coverage.hasUnresolved, isTrue);
      expect(
        derivation.limitations.join(' '),
        contains('1 modules not in the SDE'),
      );
    });

    test('T1.7 derive is pure and uses injected now', () async {
      final now = DateTime.utc(2026, 9, 11, 12);
      final derivation = await const CombatFitDeriver().derive(
        evidence: evidenceOf(armedFit()),
        subject: AarFitSubject.self,
        inputs: inputsFor(armedFit()),
        skills: allFive,
        now: now,
      );
      expect(derivation.derivedAt, now);
    });

    test('T2.1 knownCharacter Shield Management V scales MSE HP', () async {
      const skills = AarSkillContext(
        basis: AarSkillBasis.knownCharacter,
        skills: [CharacterSkill(skillId: 3419, level: 5)],
        characterId: 42,
      );
      final derivation = await const CombatFitDeriver().derive(
        evidence: evidenceOf(armedFit()),
        subject: AarFitSubject.self,
        inputs: inputsFor(armedFit()),
        skills: skills,
      );
      expect(derivation.stats.defenses.shieldHp, closeTo(1550 * 1.25, 0.01));
    });

    test(
      'T2.2 allFive with the same skill matches numbers and All V label',
      () async {
        const skills = AarSkillContext(
          basis: AarSkillBasis.allFive,
          skills: [CharacterSkill(skillId: 3419, level: 5)],
        );
        final derivation = await const CombatFitDeriver().derive(
          evidence: evidenceOf(armedFit()),
          subject: AarFitSubject.self,
          inputs: inputsFor(armedFit()),
          skills: skills,
        );
        expect(derivation.stats.defenses.shieldHp, closeTo(1550 * 1.25, 0.01));
        expect(derivation.skills.label, 'assumes All V');
      },
    );

    test('T2.3 knownCharacter confidence is strictly higher than allFive', () {
      const known = AarSkillContext(
        basis: AarSkillBasis.knownCharacter,
        skills: [],
        characterId: 1,
      );
      const allV = AarSkillContext(basis: AarSkillBasis.allFive, skills: []);
      expect(known.confidence.index, lessThan(allV.confidence.index));
    });

    test(
      'T2.5 empty skills vs engine-table All V raises shield and CPU',
      () async {
        const tableIds = [3426, 3413, 3449, 3418, 3419, 3394, 3392, 3416];
        final untrained = await const CombatFitDeriver().derive(
          evidence: evidenceOf(armedFit()),
          subject: AarFitSubject.self,
          inputs: inputsFor(armedFit()),
          skills: allFive,
        );
        final trained = await const CombatFitDeriver().derive(
          evidence: evidenceOf(armedFit()),
          subject: AarFitSubject.self,
          inputs: inputsFor(armedFit()),
          skills: AarSkillContext(
            basis: AarSkillBasis.allFive,
            skills: [
              for (final id in tableIds) CharacterSkill(skillId: id, level: 5),
            ],
          ),
        );
        expect(
          trained.stats.defenses.shieldHp,
          greaterThan(untrained.stats.defenses.shieldHp),
        );
        expect(trained.stats.cpuMax, greaterThan(untrained.stats.cpuMax));
      },
    );

    test(
      'A.8 limitations always include skill label and assumed active',
      () async {
        final derivation = await const CombatFitDeriver().derive(
          evidence: evidenceOf(armedFit()),
          subject: AarFitSubject.self,
          inputs: inputsFor(armedFit()),
          skills: allFive,
        );
        expect(derivation.limitations.join(' '), contains('assumes All V'));
        expect(derivation.limitations.join(' '), contains('assumed active'));
      },
    );

    test(
      'A.9 ancillary fitted mentions reload/overheat not modelled',
      () async {
        final fitting = Fitting(
          id: 'saar',
          name: 'Rifter SAAR',
          shipTypeId: 587,
          shipName: 'Rifter',
          lowSlots: const [
            FittedModule(
              typeId: saar,
              typeName: 'Small Ancillary Armor Repairer',
              slotType: SlotType.low,
              slotIndex: 0,
            ),
          ],
        );
        final derivation = await const CombatFitDeriver().derive(
          evidence: evidenceOf(fitting),
          subject: AarFitSubject.self,
          inputs: inputsFor(fitting),
          skills: allFive,
        );
        final text = derivation.limitations.join(' ').toLowerCase();
        expect(text, contains('reload'));
        expect(text, contains('overheat'));
      },
    );
  });
}
