import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils.dart';

void main() {
  group('formatDuration', () {
    test('formats zero duration', () {
      expect(formatDuration(Duration.zero), '0s');
    });

    test('formats seconds only', () {
      expect(formatDuration(Duration(seconds: 5)), '5s');
      expect(formatDuration(Duration(seconds: 12)), '12s');
    });

    test('formats minutes only', () {
      expect(formatDuration(Duration(minutes: 5)), '5m');
      expect(formatDuration(Duration(minutes: 45)), '45m');
    });

    test('formats hours only', () {
      expect(formatDuration(Duration(hours: 2)), '2h');
      expect(formatDuration(Duration(hours: 15)), '15h');
    });

    test('formats days only', () {
      expect(formatDuration(Duration(days: 3)), '3d');
      expect(formatDuration(Duration(days: 10)), '10d');
    });

    test('formats mixed units - minutes and seconds', () {
      expect(formatDuration(Duration(minutes: 2, seconds: 30)), '2m 30s');
      expect(formatDuration(Duration(minutes: 5, seconds: 5)), '5m 5s');
    });

    test('formats mixed units - hours and minutes', () {
      expect(formatDuration(Duration(hours: 1, minutes: 15)), '1h 15m');
      expect(formatDuration(Duration(hours: 3, minutes: 5)), '3h 5m');
    });

    test('formats mixed units - days and hours', () {
      expect(formatDuration(Duration(days: 3, hours: 4)), '3d 4h');
      expect(formatDuration(Duration(days: 5, hours: 12)), '5d 12h');
    });

    test('formats mixed units - hours and seconds (skipping zero minutes)', () {
      expect(formatDuration(Duration(hours: 1, minutes: 0, seconds: 15)),
          '1h 15s');
      expect(
          formatDuration(Duration(hours: 2, minutes: 0, seconds: 5)), '2h 5s');
    });

    test('formats mixed units - days and minutes (skipping zero hours)', () {
      expect(
          formatDuration(Duration(days: 3, hours: 0, minutes: 30)), '3d 30m');
      expect(
          formatDuration(Duration(days: 1, hours: 0, minutes: 15)), '1d 15m');
    });

    test('formats with truncation of units (only two largest)', () {
      expect(
          formatDuration(Duration(days: 1, hours: 2, minutes: 3, seconds: 4)),
          '1d 2h');
      expect(
          formatDuration(Duration(hours: 1, minutes: 2, seconds: 3)), '1h 2m');
      expect(
          formatDuration(Duration(minutes: 1, seconds: 2, milliseconds: 900)),
          '1m 2s');
    });

    test('formats sub-second durations', () {
      expect(formatDuration(Duration(milliseconds: 500)), '<1s');
      expect(formatDuration(Duration(milliseconds: 100)), '<1s');
      expect(formatDuration(Duration(microseconds: 999)), '<1s');
    });

    test('formats negative durations', () {
      expect(formatDuration(Duration(seconds: -5)), '-5s');
      expect(formatDuration(Duration(minutes: -2, seconds: -30)), '-2m 30s');
      expect(formatDuration(Duration(hours: -1, minutes: -15)), '-1h 15m');
      expect(formatDuration(Duration(milliseconds: -500)), '-<1s');
    });

    test('handles exact unit boundaries', () {
      expect(formatDuration(Duration(seconds: 59)), '59s');
      expect(formatDuration(Duration(seconds: 60)), '1m');
      expect(formatDuration(Duration(minutes: 59)), '59m');
      expect(formatDuration(Duration(minutes: 60)), '1h');
      expect(formatDuration(Duration(hours: 23)), '23h');
      expect(formatDuration(Duration(hours: 24)), '1d');
    });

    test('truncates microseconds to milliseconds', () {
      expect(formatDuration(Duration(microseconds: 1234567)), '1s');
      expect(formatDuration(Duration(microseconds: 1234999)), '1s');
    });

    test('handles millisecond boundaries', () {
      expect(formatDuration(Duration(milliseconds: 999)), '<1s');
      expect(formatDuration(Duration(milliseconds: 1000)), '1s');
    });
  });
}
