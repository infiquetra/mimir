import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('formatBytes', () {
    test('zero case', () {
      expect(formatBytes(0), '0 B');
    });

    test('bytes-only case below 1 KB', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('exact binary boundaries for promoted units', () {
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(1048576), '1 MB');
      expect(formatBytes(1073741824), '1 GB');
      expect(formatBytes(1099511627776), '1 TB');
    });

    test('fractional/rounding case', () {
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(1280), '1.25 KB');
    });

    test('negative input handling', () {
      expect(formatBytes(-2048), '-2 KB');
      expect(formatBytes(-512), '-512 B');
    });

    test('exact above-TB case', () {
      // 1024^5 = 1125899906842624
      expect(formatBytes(1125899906842624), '1024 TB');
    });
  });
}
