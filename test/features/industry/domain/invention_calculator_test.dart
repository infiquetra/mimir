import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/industry/domain/invention_calculator.dart';

void main() {
  group('InventionCalculator', () {
    test('calculates base probability with max skills and no decryptor', () {
      final chance = InventionCalculator.calculateProbability(
        baseProbability: 0.30,
        encryptionSkillLevel: 5,
        datacoreSkill1Level: 5,
        datacoreSkill2Level: 5,
      );

      // skill factor = 1.0 + 5/40 + 5/40 + 5/40 = 1.375
      // 0.30 * 1.375 = 0.4125
      expect(chance, closeTo(0.4125, 0.0001));
    });

    test('calculates base probability with max skills and symmetry decryptor', () {
      final chance = InventionCalculator.calculateProbability(
        baseProbability: 0.30,
        encryptionSkillLevel: 5,
        datacoreSkill1Level: 5,
        datacoreSkill2Level: 5,
        decryptorMultiplier: 1.1, // Symmetry adds +10% 
      );

      // 0.4125 * 1.1 = 0.45375
      expect(chance, closeTo(0.45375, 0.0001));
    });

    test('calculates base probability with optimized decryptor', () {
      final chance = InventionCalculator.calculateProbability(
        baseProbability: 0.40,
        encryptionSkillLevel: 4,
        datacoreSkill1Level: 4,
        datacoreSkill2Level: 4,
        decryptorMultiplier: 0.6, // Optimized lowers probability
      );

      // skill factor = 1.0 + 4/40 + 4/40 + 4/40 = 1.3
      // 0.40 * 1.3 = 0.52
      // 0.52 * 0.6 = 0.312
      expect(chance, closeTo(0.312, 0.0001));
    });

    test('caps probability at 1.0', () {
      final chance = InventionCalculator.calculateProbability(
        baseProbability: 0.90,
        encryptionSkillLevel: 5,
        datacoreSkill1Level: 5,
        datacoreSkill2Level: 5,
        decryptorMultiplier: 1.8,
      );

      // 0.9 * 1.375 * 1.8 = 2.2275 -> should be capped at 1.0
      expect(chance, equals(1.0));
    });
  });
}
