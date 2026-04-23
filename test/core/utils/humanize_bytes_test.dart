import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('humanizeBytes', () {
    test('zero returns 0 B', () {
      expect(humanizeBytes(0), '0 B');
    });

    test('values below 1024 stay in bytes', () {
      expect(humanizeBytes(512), '512 B');
      expect(humanizeBytes(1023), '1023 B');
    });

    test('exact unit boundary 1024 bytes -> 1 KB', () {
      expect(humanizeBytes(1024), '1 KB');
    });

    test('fractional KB values with one decimal', () {
      expect(humanizeBytes(1536), '1.5 KB');
    });

    test('fractional KB values with two decimals', () {
      expect(humanizeBytes(1264), '1.23 KB');
    });

    test('exact unit boundary 1048576 bytes -> 1 MB', () {
      expect(humanizeBytes(1048576), '1 MB');
    });

    test('GB boundary', () {
      expect(humanizeBytes(1073741824), '1 GB');
    });

    test('TB boundary', () {
      expect(humanizeBytes(1099511627776), '1 TB');
    });

    test('negative values get minus prefix', () {
      expect(humanizeBytes(-2048), '-2 KB');
    });

    test('values above TB scale numerically with TB suffix', () {
      expect(humanizeBytes(1099511627776 * 2), '2 TB');
    });

    test('values exceeding 1024 TB remain in TB unit', () {
      // 1024 TB = 1024^5 bytes; formatter should cap at TB, not advance
      expect(humanizeBytes(1099511627776 * 1024), '1024 TB');
      expect(humanizeBytes(1099511627776 * 2048), '2048 TB');
    });

    test('handles extremely large values without throwing', () {
      // Values that cause double overflow should not crash
      // max int64 (9e18) is well within double range, but we test the code path
      // The fix handles the case where value becomes double.infinity
      expect(humanizeBytes(9223372036854775807).contains('TB'), isTrue);
    });
  });
}
