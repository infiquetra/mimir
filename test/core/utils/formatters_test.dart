import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('formatBytes', () {
    test("returns '0 B' for zero", () {
      expect(formatBytes(0), '0 B');
    });

    test('handles byte boundary', () {
      expect(formatBytes(1023), '1023 B');
    });

    test('handles KB MB GB TB boundaries', () {
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(1024 * 1024), '1 MB');
      expect(formatBytes(1024 * 1024 * 1024), '1 GB');
      expect(formatBytes(1024 * 1024 * 1024 * 1024), '1 TB');
    });

    test('renders fractional values with up to 2 decimals', () {
      expect(formatBytes(1536), '1.5 KB');
      // 1.25 KB = 1024 + 256
      expect(formatBytes(1280), '1.25 KB');
      // 1.5 GB
      expect(formatBytes(1610612736), '1.5 GB');
    });

    test('trims trailing zeros on exact units', () {
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes(1048576 * 2), '2 MB');
    });

    test('prefixes negatives with minus', () {
      expect(formatBytes(-2048), '-2 KB');
      expect(formatBytes(-512), '-512 B');
    });

    test('keeps TB suffix for values above 1 TB', () {
      // 2.5 TB
      final val = 2 * 1024 * 1024 * 1024 * 1024 + 512 * 1024 * 1024 * 1024;
      expect(formatBytes(val), '2.5 TB');
      
      // Much larger value
      final largeVal = 100 * 1024 * 1024 * 1024 * 1024;
      expect(formatBytes(largeVal), '100 TB');
    });
  });
}
