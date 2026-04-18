import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/isk_formatter.dart';

void main() {
  group('formatIsk', () {
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

    test('rounds to 2 decimal places', () {
      expect(formatIsk(100.999), equals('101.00 ISK'));
      expect(formatIsk(100.994), equals('100.99 ISK'));
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
  });
}
