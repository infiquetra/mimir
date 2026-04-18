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

    // Edge case tests - non-finite values throw ArgumentError
    group('rejects non-finite values', () {
      test('throws ArgumentError for NaN', () {
        expect(
          () => formatIsk(double.nan),
          throwsArgumentError,
        );
      });

      test('throws ArgumentError for positive infinity', () {
        expect(
          () => formatIsk(double.infinity),
          throwsArgumentError,
        );
      });

      test('throws ArgumentError for negative infinity', () {
        expect(
          () => formatIsk(double.negativeInfinity),
          throwsArgumentError,
        );
      });
    });

    // Edge case tests - rounding behavior with clean decimal values
    group('handles rounding', () {
      test('rounds 100.999 to 101.00', () {
        expect(formatIsk(100.999), equals('101.00 ISK'));
      });

      test('rounds 100.994 to 100.99', () {
        expect(formatIsk(100.994), equals('100.99 ISK'));
      });

      test('rounds 0.005 to 0.01', () {
        expect(formatIsk(0.005), equals('0.01 ISK'));
      });

      test('rounds -0.005 to -0.01', () {
        expect(formatIsk(-0.005), equals('-0.01 ISK'));
      });
    });

    // Edge case tests - negative zero and near-zero values
    // Condensed into table-driven format for maintainability
    group('normalizes near-zero values', () {
      const nearZeroCases = <MapEntry<num, String>>[
        // Values with magnitude < 0.005 round to 0.00 and normalize to positive
        MapEntry(-0.001, '0.00 ISK'),
        MapEntry(0.001, '0.00 ISK'),
        MapEntry(-0.0, '0.00 ISK'),
        MapEntry(0.0, '0.00 ISK'),
        MapEntry(0.004, '0.00 ISK'),
        MapEntry(-0.004, '0.00 ISK'),
        // Values at or above 0.005 threshold round normally
        MapEntry(0.005, '0.01 ISK'),
        MapEntry(-0.005, '-0.01 ISK'),
      ];

      for (final testCase in nearZeroCases) {
        test('formats ${testCase.key} as ${testCase.value}', () {
          expect(formatIsk(testCase.key), equals(testCase.value));
        });
      }
    });
  });
}
