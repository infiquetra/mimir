import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_profile.dart';
import 'package:mimir/features/combat_analyzer/domain/tank_classifier.dart';
import 'package:mimir/features/fitting/domain/models.dart';

void main() {
  group('CombatDamageMatchupAnalyzer', () {
    test('identifies strongest and weakest resist exposure', () {
      final result = CombatDamageMatchupAnalyzer.analyze(
        profile: const CombatDamageProfile(
          totalProfiledDamage: 1000,
          unknownWeapons: [],
          entries: [
            CombatDamageTypeEstimate(
              type: 'Kinetic',
              amount: 700,
              percent: 0.7,
              confidence: CombatDamageConfidence.sdeExact,
              source: 'Scourge Rocket',
              evidence: 'SDE damage attributes',
            ),
            CombatDamageTypeEstimate(
              type: 'Explosive',
              amount: 300,
              percent: 0.3,
              confidence: CombatDamageConfidence.sdeExact,
              source: 'Nova Rocket',
              evidence: 'SDE damage attributes',
            ),
          ],
        ),
        defense: const DefenseProfile(
          shieldHp: 1000,
          shieldResists: ResistProfile(
            em: 0,
            thermal: 20,
            kinetic: 70,
            explosive: 10,
          ),
          armorHp: 500,
          armorResists: ResistProfile(
            em: 50,
            thermal: 35,
            kinetic: 25,
            explosive: 10,
          ),
          hullHp: 400,
          hullResists: ResistProfile(),
        ),
        targetLabel: 'Condor',
      );

      expect(result.entries, hasLength(2));
      expect(result.entries.first.type, 'Kinetic');
      expect(result.entries.first.resistPercent, 70);
      expect(
        result.entries.first.assessment,
        DamageMatchupAssessment.strongResist,
      );
      expect(
        result.entries.last.assessment,
        DamageMatchupAssessment.resistHole,
      );
      expect(result.summary, contains('Condor'));
    });

    CombatDamageTypeEstimate typed(String type, int amount, double percent) =>
        CombatDamageTypeEstimate(
          type: type,
          amount: amount,
          percent: percent,
          confidence: CombatDamageConfidence.sdeExact,
          source: type,
          evidence: 'fixture',
        );

    const holeLayer = ResistProfile(
      em: 10,
      thermal: 60,
      kinetic: 60,
      explosive: 60,
    );

    test('T4.1 10/60/60/60 vs 90% EM is EM hole and primaryHole EM', () {
      final result = CombatDamageMatchupAnalyzer.analyze(
        profile: CombatDamageProfile(
          totalProfiledDamage: 100,
          unknownWeapons: const [],
          entries: [typed('EM', 90, 0.9), typed('Kinetic', 10, 0.1)],
        ),
        defense: const DefenseProfile(shieldHp: 1000, shieldResists: holeLayer),
        targetLabel: 'Rifter',
      );
      expect(
        result.entries.firstWhere((e) => e.type == 'EM').assessment,
        DamageMatchupAssessment.resistHole,
      );
      expect(
        result.entries.firstWhere((e) => e.type == 'Kinetic').assessment,
        DamageMatchupAssessment.strongResist,
      );
      expect(result.primaryHole, 'EM');
    });

    test('T4.2 same resists vs 90% Kinetic is Kinetic strongResist', () {
      final result = CombatDamageMatchupAnalyzer.analyze(
        profile: CombatDamageProfile(
          totalProfiledDamage: 100,
          unknownWeapons: const [],
          entries: [typed('Kinetic', 90, 0.9), typed('EM', 10, 0.1)],
        ),
        defense: const DefenseProfile(shieldHp: 1000, shieldResists: holeLayer),
        targetLabel: 'Rifter',
      );
      expect(
        result.entries.firstWhere((e) => e.type == 'Kinetic').assessment,
        DamageMatchupAssessment.strongResist,
      );
    });

    test('T4.3 flat 50s even profile is all neutral with no primaryHole', () {
      final result = CombatDamageMatchupAnalyzer.analyze(
        profile: CombatDamageProfile(
          totalProfiledDamage: 100,
          unknownWeapons: const [],
          entries: [
            typed('EM', 25, 0.25),
            typed('Thermal', 25, 0.25),
            typed('Kinetic', 25, 0.25),
            typed('Explosive', 25, 0.25),
          ],
        ),
        defense: const DefenseProfile(
          shieldHp: 1000,
          shieldResists: ResistProfile(
            em: 50,
            thermal: 50,
            kinetic: 50,
            explosive: 50,
          ),
        ),
        targetLabel: 'Rifter',
      );
      expect(
        result.entries.every(
          (e) => e.assessment == DamageMatchupAssessment.neutral,
        ),
        isTrue,
      );
      expect(result.primaryHole, isNull);
    });

    test('T4.4 null defense yields unknown entries and no EHP', () {
      final result = CombatDamageMatchupAnalyzer.analyze(
        profile: CombatDamageProfile(
          totalProfiledDamage: 100,
          unknownWeapons: const [],
          entries: [typed('EM', 100, 1.0)],
        ),
        defense: null,
        targetLabel: 'Rifter',
      );
      expect(result.layer, 'unknown');
      expect(result.ehpAgainstPattern, isNull);
      for (final entry in result.entries) {
        expect(entry.assessment, DamageMatchupAssessment.unknown);
        expect(entry.resistPercent, isNull);
        expect(entry.appliedPercent, isNull);
      }
    });

    test('T4.5 mixed profile percents and appliedPercents sum to 1', () {
      final result = CombatDamageMatchupAnalyzer.analyze(
        profile: CombatDamageProfile(
          totalProfiledDamage: 100,
          unknownWeapons: const [],
          entries: [
            typed('EM', 30, 0.3),
            typed('Thermal', 20, 0.2),
            typed('Kinetic', 50, 0.5),
          ],
        ),
        defense: const DefenseProfile(
          shieldHp: 1000,
          shieldResists: ResistProfile(
            em: 10,
            thermal: 20,
            kinetic: 40,
            explosive: 50,
          ),
        ),
        targetLabel: 'Rifter',
      );
      final percentSum = result.entries.fold<double>(
        0,
        (a, e) => a + e.percent,
      );
      final appliedSum = result.entries.fold<double>(
        0,
        (a, e) => a + (e.appliedPercent ?? 0),
      );
      expect(percentSum, closeTo(1.0, 1e-6));
      expect(appliedSum, closeTo(1.0, 1e-6));
    });

    test('T4.7 tank armor wins even when shield HP is larger', () {
      final result = CombatDamageMatchupAnalyzer.analyze(
        profile: CombatDamageProfile(
          totalProfiledDamage: 100,
          unknownWeapons: const [],
          entries: [typed('EM', 100, 1.0)],
        ),
        defense: const DefenseProfile(
          shieldHp: 2000,
          shieldResists: ResistProfile(
            em: 0,
            thermal: 0,
            kinetic: 0,
            explosive: 0,
          ),
          armorHp: 500,
          armorResists: ResistProfile(
            em: 60,
            thermal: 35,
            kinetic: 25,
            explosive: 10,
          ),
        ),
        tank: const TankAssessment(
          layer: TankLayer.armor,
          mode: TankMode.active,
          shieldBoostHps: 0,
          armorRepairHps: 61.33,
          hullRepairHps: 0,
          shieldGainEhp: 0,
          armorGainEhp: 0,
          hullGainEhp: 0,
          reasoning: 'Armor (active)',
        ),
        targetLabel: 'Myrmidon',
      );
      expect(result.layer, 'armor');
      expect(result.entries.single.resistPercent, 60);
    });

    test('D.8 S1 armor profile: Thermal hole, Kin applied 0.676', () {
      const armorHp = 4500.0;
      const armor = ResistProfile(
        em: 52.4,
        thermal: 34.8,
        kinetic: 63.1,
        explosive: 71.2,
      );
      final result = CombatDamageMatchupAnalyzer.analyze(
        profile: CombatDamageProfile(
          totalProfiledDamage: 100,
          unknownWeapons: const [],
          entries: [
            typed('EM', 3, 0.03),
            typed('Thermal', 19, 0.19),
            typed('Kinetic', 78, 0.78),
          ],
        ),
        defense: const DefenseProfile(
          shieldHp: 5000,
          armorHp: armorHp,
          armorResists: armor,
        ),
        tank: const TankAssessment(
          layer: TankLayer.armor,
          mode: TankMode.active,
          shieldBoostHps: 0,
          armorRepairHps: 61.33,
          hullRepairHps: 0,
          shieldGainEhp: 0,
          armorGainEhp: 0,
          hullGainEhp: 0,
          reasoning: 'Armor (active)',
        ),
        targetLabel: 'Myrmidon',
      );
      expect(
        result.entries.firstWhere((e) => e.type == 'Thermal').assessment,
        DamageMatchupAssessment.resistHole,
      );
      expect(
        result.entries.firstWhere((e) => e.type == 'Kinetic').assessment,
        DamageMatchupAssessment.strongResist,
      );
      expect(
        result.entries.firstWhere((e) => e.type == 'EM').assessment,
        DamageMatchupAssessment.neutral,
      );
      expect(
        result.entries.firstWhere((e) => e.type == 'Kinetic').appliedPercent,
        closeTo(0.676, 0.001),
      );
      expect(
        result.entries.firstWhere((e) => e.type == 'Thermal').appliedPercent,
        closeTo(0.291, 0.001),
      );
      expect(
        result.entries.firstWhere((e) => e.type == 'EM').appliedPercent,
        closeTo(0.034, 0.001),
      );
      expect(result.primaryHole, 'Thermal');
      final denom = 0.03 * 0.476 + 0.19 * 0.652 + 0.78 * 0.369;
      expect(result.ehpAgainstPattern?.armor, closeTo(armorHp / denom, 0.01));
    });

    test('D.9 unknown weapons are ignored when building the pattern', () {
      final result = CombatDamageMatchupAnalyzer.analyze(
        profile: CombatDamageProfile(
          totalProfiledDamage: 100,
          unknownWeapons: const ['Mystery Gun'],
          entries: [typed('Kinetic', 100, 1.0)],
        ),
        defense: const DefenseProfile(
          shieldHp: 1000,
          shieldResists: ResistProfile(
            em: 0,
            thermal: 20,
            kinetic: 70,
            explosive: 10,
          ),
        ),
        targetLabel: 'Condor',
      );
      expect(result.pattern, isNotNull);
      expect(
        result.pattern!.em +
            result.pattern!.thermal +
            result.pattern!.kinetic +
            result.pattern!.explosive,
        closeTo(1.0, 1e-6),
      );
      expect(result.pattern!.kinetic, closeTo(1.0, 1e-6));
    });

    test('D.10 JSON round trip preserves null resist and primaryHole', () {
      const matchup = CombatDamageMatchup(
        targetLabel: 'Rifter',
        layer: 'unknown',
        summary: 'no defense',
        primaryHole: 'EM',
        entries: [
          CombatDamageMatchupEntry(
            type: 'EM',
            amount: 10,
            percent: 1,
            assessment: DamageMatchupAssessment.unknown,
            evidence: 'none',
          ),
        ],
      );
      final decoded = CombatDamageMatchup.fromJson(matchup.toJson());
      expect(decoded.entries.single.resistPercent, isNull);
      expect(decoded.entries.single.appliedPercent, isNull);
      expect(decoded.primaryHole, 'EM');
    });
  });
}
