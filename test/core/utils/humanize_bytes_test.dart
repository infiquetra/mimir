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
  });
}
