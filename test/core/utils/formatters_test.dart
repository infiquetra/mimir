import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('formatBytes', () {
    test('returns zero bytes for zero', () {
      expect(formatBytes(0), '0 B');
    });

    test('returns raw bytes below one kilobyte', () {
      expect(formatBytes(512), '512 B');
    });

    test('formats exact kilobyte boundary without trailing decimals', () {
      expect(formatBytes(1024), '1 KB');
    });

    test('formats fractional kilobytes with trimmed precision', () {
      expect(formatBytes(1536), '1.5 KB');
    });

    test('formats exact megabyte boundary without trailing decimals', () {
      expect(formatBytes(1048576), '1 MB');
    });

    test('preserves minus sign for negative byte counts', () {
      expect(formatBytes(-2048), '-2 KB');
    });

    test('rounds scaled values to at most two decimals', () {
      // 1024 * 1.1234 = 1150.3616...
      // toStringAsFixed(2) -> 1.12
      expect(formatBytes(1150), '1.12 KB'); 
      // 1024 * 1.1 = 1126.4
      expect(formatBytes(1126), '1.1 KB');
    });

    test('keeps tb suffix for values above one terabyte', () {
      // 2 * 1024^4 = 2199023255552
      expect(formatBytes(2199023255552), '2 TB');
      // 2048 * 1024^4 = 2251799813685248
      expect(formatBytes(2251799813685248), '2048 TB');
    });
  });
}
