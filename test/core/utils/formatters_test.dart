import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('formatOrderDuration', () {
    test('formats days and hours correctly', () {
      final duration = const Duration(days: 2, hours: 4, minutes: 30);
      expect(formatOrderDuration(duration), equals('2d 4h 30m remaining'));
    });

    test('formats hours and minutes when no days', () {
      final duration = const Duration(hours: 4, minutes: 15);
      expect(formatOrderDuration(duration), equals('4h 15m remaining'));
    });

    test('formats minutes only when no hours or days', () {
      final duration = const Duration(minutes: 32);
      expect(formatOrderDuration(duration), equals('32m remaining'));
    });

    test('returns "Expired" for Duration.zero', () {
      expect(formatOrderDuration(Duration.zero), equals('Expired'));
    });

    test('formats days only when no hours or minutes', () {
      final duration = const Duration(days: 5);
      expect(formatOrderDuration(duration), equals('5d remaining'));
    });

    test('formats 1 day 0 hours correctly', () {
      final duration = const Duration(days: 1, hours: 0, minutes: 0);
      expect(formatOrderDuration(duration), equals('1d remaining'));
    });
  });
}
