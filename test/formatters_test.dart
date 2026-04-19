import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('Formatters', () {
    group('formatBytes', () {
      test('formats zero bytes correctly', () {
        expect(Formatters.formatBytes(0), '0 B');
      });

      test('formats bytes less than 1KB correctly', () {
        expect(Formatters.formatBytes(1), '1 B');
        expect(Formatters.formatBytes(512), '512 B');
        expect(Formatters.formatBytes(1023), '1023 B');
      });

      test('formats exactly 1KB correctly', () {
        expect(Formatters.formatBytes(1024), '1 KB');
      });

      test('formats fractional KB correctly', () {
        expect(Formatters.formatBytes(1536), '1.5 KB');
        expect(Formatters.formatBytes(2048), '2 KB');
        expect(Formatters.formatBytes(1800), '1.76 KB');
      });

      test('formats exactly 1MB correctly', () {
        expect(Formatters.formatBytes(1024 * 1024), '1 MB');
      });

      test('formats fractional MB correctly', () {
        expect(Formatters.formatBytes(1024 * 1024 + 512 * 1024), '1.5 MB');
        expect(Formatters.formatBytes(2 * 1024 * 1024), '2 MB');
      });

      test('formats exactly 1GB correctly', () {
        expect(Formatters.formatBytes(1024 * 1024 * 1024), '1 GB');
      });

      test('formats fractional GB correctly', () {
        expect(
            Formatters.formatBytes((1024 * 1024 * 1024) + (512 * 1024 * 1024)),
            '1.5 GB');
        expect(Formatters.formatBytes(2 * 1024 * 1024 * 1024), '2 GB');
      });

      test('formats exactly 1TB correctly', () {
        expect(Formatters.formatBytes(1024 * 1024 * 1024 * 1024), '1 TB');
      });

      test('formats beyond 1TB correctly', () {
        expect(Formatters.formatBytes(1024 * 1024 * 1024 * 1024 * 2), '2 TB');
        expect(Formatters.formatBytes(1024 * 1024 * 1024 * 1024 * 1024),
            '1024 TB');
      });

      test('handles negative values correctly', () {
        expect(Formatters.formatBytes(-1), '-1 B');
        expect(Formatters.formatBytes(-1024), '-1 KB');
        expect(Formatters.formatBytes(-1536), '-1.5 KB');
        expect(Formatters.formatBytes(-1024 * 1024), '-1 MB');
      });

      test('removes trailing zeros correctly', () {
        // This test ensures that numbers like 1.00 are displayed as 1
        // The implementation should handle this by checking if the number
        // is a whole number and formatting accordingly
        expect(Formatters.formatBytes(1024), '1 KB'); // Exactly 1 KB
        expect(Formatters.formatBytes(2048), '2 KB'); // Exactly 2 KB
        expect(Formatters.formatBytes(1536), '1.5 KB'); // Fractional KB
      });
    });
  });
}
