import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/isk_formatter.dart';

void main() {
  group('formatIsk', () {
    // Happy path tests - table-driven for maintainability
    group('formats valid ISK amounts', () {
      const testCases = <MapEntry<num, String>>[
        MapEntry(1234567.89, '1,234,567.89 ISK'),
        MapEntry(0, '0.00 ISK'),
        MapEntry(-500.5, '-500.50 ISK'),
        MapEntry(1000000000000.0, '1,000,000,000,000.00 ISK'),
        MapEntry(42.5, '42.50 ISK'),
        MapEntry(999.99, '999.99 ISK'),
        MapEntry(1000.0, '1,000.00 ISK'),
        MapEntry(-1234567.89, '-1,234,567.89 ISK'),
        MapEntry(500.0, '500.00 ISK'),
        MapEntry(5000000.0, '5,000,000.00 ISK'),
        MapEntry(3500000000.0, '3,500,000,000.00 ISK'),
        MapEntry(1000, '1,000.00 ISK'), // integer input
        MapEntry(999999999, '999,999,999.00 ISK'), // large integer input
      ];

      for (final testCase in testCases) {
        test('formats ${testCase.key} correctly', () {
          expect(formatIsk(testCase.key), equals(testCase.value));
        });
      }
    });

    // Edge case tests - non-finite values
    group('handles non-finite values', () {
      test('returns invalid message for NaN', () {
        expect(formatIsk(double.nan), equals('Invalid ISK amount'));
      });

      test('returns invalid message for positive infinity', () {
        expect(formatIsk(double.infinity), equals('Invalid ISK amount'));
      });

      test('returns invalid message for negative infinity', () {
        expect(
            formatIsk(double.negativeInfinity), equals('Invalid ISK amount'));
      });
    });

    // Edge case tests - floating-point rounding behavior
    group('handles floating-point rounding', () {
      test('rounds 1.005 to 1.00 (standard rounding)', () {
        // 1.005 in binary floating-point is slightly less than 1.005
        // NumberFormat applies standard rounding rules to the actual value
        expect(formatIsk(1.005), equals('1.00 ISK'));
      });

      test('rounds 2.675 consistently', () {
        // 2.675 in binary FP representation is slightly less than 2.675
        // NumberFormat applies standard rounding to the actual stored value
        expect(formatIsk(2.675), equals('2.67 ISK'));
      });

      test('rounds 100.999 to 101.00', () {
        expect(formatIsk(100.999), equals('101.00 ISK'));
      });

      test('rounds 100.994 to 100.99', () {
        expect(formatIsk(100.994), equals('100.99 ISK'));
      });
    });

    // Edge case tests - negative zero and near-zero values
    group('normalizes negative zero and near-zero values', () {
      test('handles -0.001 (rounds to zero)', () {
        // -0.001 has magnitude < 0.005, so it normalizes to positive zero
        expect(formatIsk(-0.001), equals('0.00 ISK'));
      });

      test('handles 0.001 (rounds to zero)', () {
        expect(formatIsk(0.001), equals('0.00 ISK'));
      });

      test('handles -0.0 explicitly', () {
        expect(formatIsk(-0.0), equals('0.00 ISK'));
      });

      test('handles values at rounding boundary (0.004)', () {
        expect(formatIsk(0.004), equals('0.00 ISK'));
      });

      test('handles values at rounding boundary (-0.004)', () {
        expect(formatIsk(-0.004), equals('0.00 ISK'));
      });

      test('handles values just above rounding boundary (0.005)', () {
        expect(formatIsk(0.005), equals('0.01 ISK'));
      });

      test('handles values just above rounding boundary (-0.005)', () {
        expect(formatIsk(-0.005), equals('-0.01 ISK'));
      });
    });
  });
}
