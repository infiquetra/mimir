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

  group('formatIskCompact()', () {
    test('formats thousands with K suffix', () {
      expect(formatIskCompact(1234), '1.23K ISK');
      expect(formatIskCompact(5000), '5.00K ISK');
      expect(formatIskCompact(9999), '10.00K ISK');
    });

    test('formats millions with M suffix', () {
      expect(formatIskCompact(1234567), '1.23M ISK');
      expect(formatIskCompact(5000000), '5.00M ISK');
      expect(formatIskCompact(9999999), '10.00M ISK');
    });

    test('formats billions with B suffix', () {
      expect(formatIskCompact(1234567890), '1.23B ISK');
      expect(formatIskCompact(5000000000), '5.00B ISK');
      expect(formatIskCompact(9999999999), '10.00B ISK');
    });

    test('formats trillions with T suffix', () {
      expect(formatIskCompact(1234567890000), '1.23T ISK');
      expect(formatIskCompact(5000000000000), '5.00T ISK');
    });

    test('formats values below 1000 without suffix', () {
      expect(formatIskCompact(0), '0.00 ISK');
      expect(formatIskCompact(100), '100.00 ISK');
      expect(formatIskCompact(999.99), '999.99 ISK');
      expect(formatIskCompact(50), '50.00 ISK');
    });

    test('handles exact thresholds correctly', () {
      expect(formatIskCompact(1000), '1.00K ISK');
      expect(formatIskCompact(1000000), '1.00M ISK');
      expect(formatIskCompact(1000000000), '1.00B ISK');
      expect(formatIskCompact(1000000000000), '1.00T ISK');
    });

    test('handles just-below thresholds (boundary rollover)', () {
      expect(formatIskCompact(999), '999.00 ISK');
      expect(formatIskCompact(999.99), '999.99 ISK');
      expect(formatIskCompact(999999), '1.00M ISK');
      expect(formatIskCompact(999999.99), '1.00M ISK');
      expect(formatIskCompact(999999999), '1.00B ISK');
      expect(formatIskCompact(999999999.99), '1.00B ISK');
    });

    test('handles negative values', () {
      expect(formatIskCompact(-1234), '-1.23K ISK');
      expect(formatIskCompact(-5000000), '-5.00M ISK');
      expect(formatIskCompact(-1000), '-1.00K ISK');
      expect(formatIskCompact(-500), '-500.00 ISK');
    });

    test('handles NaN and infinity', () {
      expect(formatIskCompact(double.nan), '0.00 ISK');
      expect(formatIskCompact(double.infinity), '0.00 ISK');
      expect(formatIskCompact(double.negativeInfinity), '0.00 ISK');
    });

    test('handles rollover from rounding', () {
      // 999999 should roll to 1.00M, not 1000.00K
      expect(formatIskCompact(999999), '1.00M ISK');
      // 999999999 should roll to 1.00B, not 1000.00M
      expect(formatIskCompact(999999999), '1.00B ISK');
      // 999999999999 should roll to 1.00T, not 1000.00B
      expect(formatIskCompact(999999999999), '1.00T ISK');
    });
  });

  group('formatSnakeCase()', () {
    test('formats simple snake_case', () {
      expect(formatSnakeCase('player_trading'), 'Player Trading');
      expect(formatSnakeCase('bounty_prizes'), 'Bounty Prizes');
    });

    test('formats longer snake_case strings', () {
      expect(
        formatSnakeCase('corporation_account_withdrawal'),
        'Corporation Account Withdrawal',
      );
    });

    test('handles uppercase input', () {
      expect(formatSnakeCase('PLAYER_TRADING'), 'Player Trading');
      expect(formatSnakeCase('Bounty_Prizes'), 'Bounty Prizes');
    });

    test('handles mixed case input', () {
      expect(formatSnakeCase('player_TRADING'), 'Player Trading');
      expect(formatSnakeCase('CORPORATION_account'), 'Corporation Account');
    });

    test('filters empty segments from multiple underscores', () {
      expect(formatSnakeCase('__foo__bar__'), 'Foo Bar');
      expect(formatSnakeCase('a__b___c'), 'A B C');
    });

    test('handles leading and trailing underscores', () {
      expect(formatSnakeCase('_foo'), 'Foo');
      expect(formatSnakeCase('foo_'), 'Foo');
      expect(formatSnakeCase('_foo_'), 'Foo');
    });

    test('handles single word', () {
      expect(formatSnakeCase('player'), 'Player');
      expect(formatSnakeCase('PLAYER'), 'Player');
      expect(formatSnakeCase(''), '');
    });
  });

  group('formatIsk() edge cases', () {
    test('handles NaN', () {
      expect(formatIsk(double.nan), '0.00 ISK');
    });

    test('handles infinity', () {
      expect(formatIsk(double.infinity), '0.00 ISK');
      expect(formatIsk(double.negativeInfinity), '0.00 ISK');
    });

    test('handles very large values', () {
      expect(formatIsk(1e15), '1,000,000,000,000,000.00 ISK');
      expect(formatIsk(999999999999999), '999,999,999,999,999.00 ISK');
    });

    test('handles negative zero', () {
      expect(formatIsk(-0.0), '0.00 ISK');
    });
  });
}
