import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('formatIsk', () {
    group('standard format (amounts < 1M)', () {
      test('formats small amounts correctly', () {
        expect(formatIsk(100.0), equals('100.00 ISK'));
        expect(formatIsk(1234.56), equals('1,234.56 ISK'));
        expect(formatIsk(12345.67), equals('12,345.67 ISK'));
        expect(formatIsk(123456.78), equals('123,456.78 ISK'));
      });

      test('formats amounts close to 1M correctly', () {
        expect(formatIsk(0.0), equals('0.00 ISK'));
        expect(formatIsk(999999.99), equals('999,999.99 ISK'));
        expect(formatIsk(500000.0), equals('500,000.00 ISK'));
      });

      test('formats amounts with decimal precision correctly', () {
        expect(formatIsk(1000.1), equals('1,000.10 ISK'));
        expect(formatIsk(1000.123), equals('1,000.12 ISK'));
        expect(formatIsk(1000.999), equals('1,001.00 ISK'));
      });
    });

    group('millions format (1M <= amount < 1B)', () {
      test('formats millions correctly', () {
        expect(formatIsk(1000000.0), equals('1.00M ISK'));
        expect(formatIsk(1500000.0), equals('1.50M ISK'));
        expect(formatIsk(2000000.0), equals('2.00M ISK'));
        expect(formatIsk(15000000.0), equals('15.00M ISK'));
        expect(formatIsk(100000000.0), equals('100.00M ISK'));
      });

      test('formats millions with decimals correctly', () {
        expect(formatIsk(1234567.89), equals('1.23M ISK'));
        // Boundary: rounds to 1.00B ISK instead of 1000.00M ISK
        expect(formatIsk(999999999.99), equals('1.00B ISK'));
      });
    });

    group('billions format (amount >= 1B)', () {
      test('formats billions correctly', () {
        expect(formatIsk(1000000000.0), equals('1.00B ISK'));
        expect(formatIsk(2300000000.0), equals('2.30B ISK'));
        expect(formatIsk(5000000000.0), equals('5.00B ISK'));
        expect(formatIsk(10000000000.0), equals('10.00B ISK'));
      });

      test('formats billions with decimals correctly', () {
        expect(formatIsk(1234567890.12), equals('1.23B ISK'));
        // Boundary: rounds to 1.00T (but we don't have T suffix, so 1000.00B)
        expect(formatIsk(999999999999.99), equals('1000.00B ISK'));
      });
    });

    group('edge cases', () {
      test('handles zero', () {
        expect(formatIsk(0.0), equals('0.00 ISK'));
      });

      test('handles negative amounts', () {
        expect(formatIsk(-1000.0), equals('-1,000.00 ISK'));
        expect(formatIsk(-1500000.0), equals('-1.50M ISK'));
        expect(formatIsk(-2300000000.0), equals('-2.30B ISK'));
      });

      test('handles non-finite values', () {
        expect(formatIsk(double.nan), equals('Invalid ISK'));
        expect(formatIsk(double.infinity), equals('Invalid ISK'));
        expect(formatIsk(double.negativeInfinity), equals('Invalid ISK'));
      });

      test('handles boundary rounding correctly', () {
        // 999999.995 rounds to 1000000.00 → 1.00M ISK
        expect(formatIsk(999999.995), equals('1.00M ISK'));
        // 999999999.995 rounds to 1000000000.00 → 1.00B ISK
        expect(formatIsk(999999999.995), equals('1.00B ISK'));
      });
    });
  });
}
