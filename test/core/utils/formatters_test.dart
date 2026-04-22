import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('formatBytes', () {
    test('returns 0 B for zero bytes', () {
      expect(formatBytes(0), '0 B');
    });

    test('returns raw bytes below 1 KB', () {
      expect(formatBytes(512), '512 B');
    });

    test('formats exact KB/MB/GB boundaries without trailing decimals', () {
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(1048576), '1 MB');
      expect(formatBytes(1073741824), '1 GB');
    });

    test('adds minus prefix for negative byte counts', () {
      expect(formatBytes(-2048), '-2 KB');
      expect(formatBytes(-512), '-512 B');
    });

    test('keeps one fractional digit when trailing zeroes can be trimmed', () {
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(1280), '1.25 KB');
    });

    test('does not round one byte below 1 MB up to 1024 KB', () {
      // Regression test: 1048575 bytes should format as 1023.99 KB, not 1024 KB
      expect(formatBytes(1048575), '1023.99 KB');
    });

    test('keeps TB suffix for values above 1 TB', () {
      // 1024^5 = 1125899906842624
      expect(formatBytes(1125899906842624), '1024 TB');
    });
  });
}
