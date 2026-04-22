import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('formatBytes', () {
    test('zero returns 0 B', () {
      expect(formatBytes(0), '0 B');
    });

    test('bytes below 1 KB display as raw bytes', () {
      expect(formatBytes(512), '512 B');
    });

    test('exact 1 KB boundary renders as 1 KB', () {
      expect(formatBytes(1024), '1 KB');
    });

    test('exact 1 MB boundary renders as 1 MB', () {
      expect(formatBytes(1048576), '1 MB');
    });

    test('negative values preserve sign and scale correctly', () {
      expect(formatBytes(-2048), '-2 KB');
    });

    test('fractional values round to up to 2 decimals', () {
      expect(formatBytes(1536), '1.5 KB');
    });

    test('above TB keeps TB suffix and scales numerically', () {
      // 1024^5 = 1125899906842624 → should be 1024 TB
      expect(formatBytes(1125899906842624), '1024 TB');
    });
  });
}
