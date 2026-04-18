import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('formatIsk()', () {
    test('formats positive amount with commas and decimals', () {
      expect(formatIsk(1234567.89), '1,234,567.89 ISK');
    });

    test('formats negative amount with minus sign', () {
      expect(formatIsk(-50000), '-50,000.00 ISK');
    });

    test('formats large amounts correctly', () {
      expect(formatIsk(1000000000), '1,000,000,000.00 ISK');
    });

    test('formats zero correctly', () {
      expect(formatIsk(0), '0.00 ISK');
    });

    test('formats small amounts with decimals', () {
      expect(formatIsk(100), '100.00 ISK');
      expect(formatIsk(999.99), '999.99 ISK');
    });

    test('formats amounts without fractional part', () {
      expect(formatIsk(500000), '500,000.00 ISK');
    });
  });

  group('formatDuration()', () {
    test('formats days, hours, and minutes', () {
      final duration = const Duration(days: 2, hours: 4, minutes: 32);
      expect(formatDuration(duration), '2d 4h 32m');
    });

    test('formats hours and minutes', () {
      final duration = const Duration(hours: 4, minutes: 15);
      expect(formatDuration(duration), '4h 15m');
    });

    test('formats only minutes', () {
      final duration = const Duration(minutes: 32);
      expect(formatDuration(duration), '32m');
    });

    test('formats only hours', () {
      final duration = const Duration(hours: 5);
      expect(formatDuration(duration), '5h');
    });

    test('formats only days', () {
      final duration = const Duration(days: 3);
      expect(formatDuration(duration), '3d');
    });

    test('returns "< 1m" for sub-minute durations', () {
      expect(formatDuration(const Duration(seconds: 30)), '< 1m');
      expect(formatDuration(const Duration(seconds: 45)), '< 1m');
      expect(formatDuration(const Duration(seconds: 59)), '< 1m');
    });

    test('returns "0m" for zero duration', () {
      expect(formatDuration(Duration.zero), '0m');
    });

    test('returns "0m" for negative durations', () {
      expect(formatDuration(const Duration(seconds: -30)), '0m');
      expect(formatDuration(const Duration(minutes: -5)), '0m');
      expect(formatDuration(const Duration(hours: -2)), '0m');
    });

    test('formats complex durations correctly', () {
      // 1 day, 0 hours, 30 minutes
      expect(
        formatDuration(const Duration(days: 1, minutes: 30)),
        '1d 30m',
      );

      // 0 days, 23 hours, 59 minutes
      expect(
        formatDuration(const Duration(hours: 23, minutes: 59)),
        '23h 59m',
      );

      // Multiple days with hours
      expect(
        formatDuration(const Duration(days: 5, hours: 12)),
        '5d 12h',
      );
    });

    test('handles edge case of exactly 1 minute', () {
      expect(formatDuration(const Duration(minutes: 1)), '1m');
    });

    test('handles large durations', () {
      expect(
        formatDuration(const Duration(days: 365, hours: 6, minutes: 15)),
        '365d 6h 15m',
      );
    });
  });
}
