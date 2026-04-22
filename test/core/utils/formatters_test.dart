import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('formatBytes', () {
    test('zero returns 0 B', () {
      expect(formatBytes(0), '0 B');
    });

    test('bytes below 1 KB display as raw bytes', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('exact 1 KB boundary renders as 1 KB', () {
      expect(formatBytes(1024), '1 KB');
    });

    test('exact 1 MB boundary renders as 1 MB', () {
      expect(formatBytes(1048576), '1 MB');
    });

    test('exact 1 GB boundary renders as 1 GB', () {
      expect(formatBytes(1073741824), '1 GB');
    });

    test('exact 1 TB boundary renders as 1 TB', () {
      expect(formatBytes(1099511627776), '1 TB');
    });

    test('negative values preserve sign and scale correctly', () {
      expect(formatBytes(-2048), '-2 KB');
    });

    test('fractional values round to up to 2 decimals', () {
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(1280), '1.25 KB');
    });

    test('above TB keeps TB suffix and scales numerically', () {
      // 1024^5 = 1125899906842624 → should be 1024 TB
      expect(formatBytes(1125899906842624), '1024 TB');
    });

    test('values just below a unit boundary round correctly', () {
      // 1048575 is one byte below 1 MB; should not round up to 1024 KB
      expect(formatBytes(1048575), '1 MB');
      // 1073741823 is one byte below 1 GB
      expect(formatBytes(1073741823), '1 GB');
    });
  });
}
