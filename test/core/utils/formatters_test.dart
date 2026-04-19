import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('formatBytes', () {
    // Happy path tests
    test('returns 0 B for zero bytes', () {
      expect(formatBytes(0), '0 B');
    });

    test('returns bytes for values below 1024', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('returns KB at boundary', () {
      expect(formatBytes(1024), '1 KB');
    });

    test('returns KB with one decimal place', () {
      expect(formatBytes(1536), '1.5 KB');
    });

    test('returns KB with two decimal places', () {
      expect(formatBytes(1280), '1.25 KB');
    });

    test('returns MB at boundary', () {
      expect(formatBytes(1048576), '1 MB'); // 1024 * 1024
    });

    test('returns MB with one decimal place', () {
      expect(formatBytes(1572864), '1.5 MB'); // 1.5 * 1024 * 1024
    });

    test('returns GB at boundary', () {
      expect(formatBytes(1073741824), '1 GB'); // 1024^3
    });

    test('returns GB with one decimal place', () {
      expect(formatBytes(1610612736), '1.5 GB'); // 1.5 * 1024^3
    });

    test('returns TB at boundary', () {
      expect(formatBytes(1099511627776), '1 TB'); // 1024^4
    });

    test('returns TB with one decimal place', () {
      expect(formatBytes(1649267441664), '1.5 TB'); // 1.5 * 1024^4
    });

    // Edge case: Rounding boundaries - ensure values just below don't round up
    test('does not round up to next unit prematurely', () {
      // Just below 1 KB boundary
      expect(formatBytes(1023), '1023 B');
      // Just below 1 MB boundary
      expect(formatBytes(1048575), '1024 KB'); // 1024^2 - 1
      // Just below 1 GB boundary
      expect(formatBytes(1073741823), '1024 MB'); // 1024^3 - 1
      // Just below 1 TB boundary
      expect(formatBytes(1099511627775), '1024 GB'); // 1024^4 - 1
    });

    // Edge case: Negative values
    test('handles negative bytes', () {
      expect(formatBytes(-1024), '-1 KB');
      expect(formatBytes(-1536), '-1.5 KB');
      expect(formatBytes(-1048576), '-1 MB');
      expect(formatBytes(-512), '-512 B');
    });

    // Edge case: No negative zero
    test('does not produce negative zero', () {
      expect(formatBytes(0), '0 B');
    });

    // Edge case: Trailing zero trimming
    test('trims trailing zeros correctly', () {
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes(2097152), '2 MB'); // 2 * 1024^2
      expect(formatBytes(2147483648), '2 GB'); // 2 * 1024^3
      expect(formatBytes(2199023255552), '2 TB'); // 2 * 1024^4
    });

    // Edge case: Large TB values with decimal precision
    test('scales large values within TB with decimal precision', () {
      // 1.5 TB
      expect(formatBytes(1649267441664), '1.5 TB');
      // 5 TB
      expect(formatBytes(5497558138880), '5 TB');
      // 1024 TB
      expect(formatBytes(1125899906842624), '1024 TB');
    });

    test('formats TB with two decimal places when needed', () {
      // Value that produces exactly 2 decimals in TB (1.25 TB = 1024^4 + 1024^3/4)
      expect(formatBytes(1374389534720), '1.25 TB'); // 1.25 * 1024^4
    });

    // Edge case: Large values use TB (not sci notation)
    test('uses TB for values above 1 TB, not scientific notation', () {
      // Very large value: 100 TB
      final veryLarge = 109951162777600; // 100 * 1024^4
      final result = formatBytes(veryLarge);
      expect(result, '100 TB');
      // Verify no scientific notation
      expect(result.contains('e'), false);
      expect(result.contains('E'), false);
    });
  });
}
