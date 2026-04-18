import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/isk_formatter.dart';

void main() {
  group('formatIsk', () {
    // Happy path tests
    test('formats positive number with decimals', () {
      expect(formatIsk(1234567.89), equals('1,234,567.89 ISK'));
    });

    test('formats zero', () {
      expect(formatIsk(0), equals('0.00 ISK'));
    });

    test('formats negative values', () {
      expect(formatIsk(-500.5), equals('-500.50 ISK'));
    });

    test('formats very large numbers (trillions)', () {
      expect(formatIsk(1000000000000.0), equals('1,000,000,000,000.00 ISK'));
    });

    test('formats small positive numbers', () {
      expect(formatIsk(42.5), equals('42.50 ISK'));
    });

    test('formats numbers without thousands separator', () {
      expect(formatIsk(999.99), equals('999.99 ISK'));
    });

    test('formats numbers at thousand boundary', () {
      expect(formatIsk(1000.0), equals('1,000.00 ISK'));
    });

    test('formats negative large numbers', () {
      expect(formatIsk(-1234567.89), equals('-1,234,567.89 ISK'));
    });

    test('formats numbers with only integer part', () {
      expect(formatIsk(500.0), equals('500.00 ISK'));
    });

    test('formats millions correctly', () {
      expect(formatIsk(5000000.0), equals('5,000,000.00 ISK'));
    });

    test('formats billions correctly', () {
      expect(formatIsk(3500000000.0), equals('3,500,000,000.00 ISK'));
    });

    // Edge case tests - non-finite values
    test('returns invalid message for NaN', () {
      expect(formatIsk(double.nan), equals('Invalid ISK amount'));
    });

    test('returns invalid message for positive infinity', () {
      expect(formatIsk(double.infinity), equals('Invalid ISK amount'));
    });

    test('returns invalid message for negative infinity', () {
      expect(formatIsk(double.negativeInfinity), equals('Invalid ISK amount'));
    });

    // Edge case tests - floating-point rounding behavior
    // Note: NumberFormat uses standard rounding, which may differ from manual rounding
    // for certain floating-point edge cases due to binary representation
    test('handles floating-point rounding case 1.005', () {
      // 1.005 in binary floating-point is actually slightly less than 1.005
      // NumberFormat correctly rounds this to 1.00 (banker's rounding behavior)
      expect(formatIsk(1.005), equals('1.00 ISK'));
    });

    test('handles floating-point rounding case 2.675', () {
      // 2.675 in binary FP representation - NumberFormat handles consistently
      final result = formatIsk(2.675);
      // Just verify it produces valid formatted output
      expect(result, anyOf(equals('2.67 ISK'), equals('2.68 ISK')));
    });

    test('handles borderline float cases like 100.999', () {
      expect(formatIsk(100.999), equals('101.00 ISK'));
    });

    test('handles borderline float cases like 100.994', () {
      expect(formatIsk(100.994), equals('100.99 ISK'));
    });

    // Edge case tests - negative zero and near-zero values
    test('handles negative values that round to zero', () {
      // -0.001 rounds to -0.00, which we normalize to 0.00
      expect(formatIsk(-0.001), equals('0.00 ISK'));
    });

    test('handles extremely small positive values', () {
      expect(formatIsk(0.001), equals('0.00 ISK'));
    });

    test('handles extremely small negative values', () {
      expect(formatIsk(-0.001), equals('0.00 ISK'));
    });

    test('handles negative zero explicitly', () {
      expect(formatIsk(-0.0), equals('0.00 ISK'));
    });

    // Test with num type (int values)
    test('accepts integer values as num', () {
      expect(formatIsk(1000), equals('1,000.00 ISK'));
    });

    test('accepts large integer values as num', () {
      expect(formatIsk(999999999), equals('999,999,999.00 ISK'));
    });
  });
}
