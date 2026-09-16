// C0 RED contracts for ExactDecimal.
// Naive double stubs load so these fail as assertions, not missing imports.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_decimal.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  group('ExactDecimal lexeme and exponents', () {
    test('preserves scale in 10.00', () {
      expect(ExactDecimal.parse('10.00').toExactString(), '10.00');
      expect(ExactDecimal.parse('10.00').lexeme, '10.00');
    });

    test('rejects extreme exponents before expansion', () {
      expect(
        () => ExactDecimal.parse('1e999999999'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ExactDecimal.parse('-1e999999999'),
        throwsA(isA<FormatException>()),
      );
    });

    test('0.1 + 0.2 is exactly 0.3', () {
      final sum = ExactDecimal.parse('0.1') + ExactDecimal.parse('0.2');
      expect(sum.toExactString(), '0.3');
    });

    test('coefficient and scale reconstruct the lexeme', () {
      final amount = ExactDecimal.parse('200.20');
      expect(amount.coefficient, BigInt.from(20020));
      expect(amount.scale, 2);
      expect(amount.toExactString(), '200.20');
    });
  });

  group('F3/F5 money', () {
    test('F5 all-division total is 1500.00', () {
      final total = F5Fixtures.balances().reduce((a, b) => a + b);
      expect(total.toExactString(), '1500.00');
    });

    test('F5 missing division 7 is 1200.00 not coerced to 1500', () {
      final known = F5Fixtures.balances().take(6).reduce((a, b) => a + b);
      expect(known.toExactString(), '1200.00');
    });

    test('F5 buy gross 1.005 × 3 is 3.015 displayed 3.02', () {
      final gross = ExactDecimal.parse('1.005') * ExactDecimal.parse('3');
      expect(gross.toExactString(), '3.015');
      expect(gross.roundTo(2).toExactString(), '3.02');
    });

    test('F3 division 2 subtotal is 165.00', () {
      final crate = ExactDecimal.parse('100');
      final ammo = ExactDecimal.parse('2.50') * ExactDecimal.parse('10');
      final fuel = ExactDecimal.parse('10') * ExactDecimal.parse('4');
      expect((crate + ammo + fuel).toExactString(), '165.00');
    });
  });
}
