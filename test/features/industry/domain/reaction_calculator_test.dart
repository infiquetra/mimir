import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/industry/domain/reaction_calculator.dart';

void main() {
  group('ReactionCalculator', () {
    test('calculates inputs without facility bonus', () {
      final baseInputs = {16641: 100, 16642: 100};

      final inputs = ReactionCalculator.calculateInputs(baseInputs, 1);

      expect(inputs[16641], equals(100));
      expect(inputs[16642], equals(100));
    });

    test('calculates inputs with facility bonus', () {
      final baseInputs = {16641: 100, 16642: 100};

      // 4.8% bonus -> 100 * (1 - 0.048) = 95.2 -> round to 95
      final inputs = ReactionCalculator.calculateInputs(
        baseInputs,
        1,
        facilityMaterialBonus: 0.048,
      );

      expect(inputs[16641], equals(95));
      expect(inputs[16642], equals(95));
    });

    test('calculates inputs with multiple runs', () {
      final baseInputs = {16641: 100, 16642: 100};

      // 10 runs = 1000 base
      // 4.8% bonus -> 1000 * (1 - 0.048) = 952
      final inputs = ReactionCalculator.calculateInputs(
        baseInputs,
        10,
        facilityMaterialBonus: 0.048,
      );

      expect(inputs[16641], equals(952));
      expect(inputs[16642], equals(952));
    });

    test('calculates outputs correctly', () {
      final baseOutputs = {16654: 10};

      final outputs = ReactionCalculator.calculateOutputs(baseOutputs, 5);

      expect(outputs[16654], equals(50));
    });
  });
}
