import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_profile.dart';
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
  });
}
