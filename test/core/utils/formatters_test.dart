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
      expect(formatBytes(1280), '1.25 KB');
    });

    test('keeps tb suffix for values above one terabyte', () {
      expect(formatBytes(2199023255552), '2 TB');
      expect(formatBytes(1125899906842624), '1024 TB');
    });
  });
}
