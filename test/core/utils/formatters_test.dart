import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('formatBytes', () {
    // Zero case
    test('should format 0 as "0 B"', () {
      expect(formatBytes(0), equals('0 B'));
    });

    // Positive values in B range
    test('should format 1 as "1 B"', () {
      expect(formatBytes(1), equals('1 B'));
    });

    test('should format 512 as "512 B"', () {
      expect(formatBytes(512), equals('512 B'));
    });

    test('should format 1023 as "1023 B"', () {
      expect(formatBytes(1023), equals('1023 B'));
    });

    // KB boundary
    test('should format 1024 as "1 KB"', () {
      expect(formatBytes(1024), equals('1 KB'));
    });

    test('should format 1536 as "1.5 KB"', () {
      expect(formatBytes(1536), equals('1.5 KB'));
    });

    test('should format 2048 as "2 KB"', () {
      expect(formatBytes(2048), equals('2 KB'));
    });

    // MB boundary
    test('should format 1024 * 1024 as "1 MB"', () {
      expect(formatBytes(1024 * 1024), equals('1 MB'));
    });

    test('should format 1048576 as "1 MB"', () {
      expect(formatBytes(1048576), equals('1 MB'));
    });

    test('should format 1572864 as "1.5 MB"', () {
      expect(formatBytes(1572864), equals('1.5 MB'));
    });

    // GB boundary
    test('should format 1024 * 1024 * 1024 as "1 GB"', () {
      expect(formatBytes(1024 * 1024 * 1024), equals('1 GB'));
    });

    test('should format 1610612736 as "1.5 GB"', () {
      expect(formatBytes(1610612736), equals('1.5 GB'));
    });

    // TB boundary
    test('should format 1024 * 1024 * 1024 * 1024 as "1 TB"', () {
      expect(formatBytes(1024 * 1024 * 1024 * 1024), equals('1 TB'));
    });

    test('should format 1649267441664 as "1.5 TB"', () {
      expect(formatBytes(1649267441664), equals('1.5 TB'));
    });

    // Above TB - scales within TB (e.g., 1024 TB)
    test('should format above TB within TB units', () {
      final aboveTB = 1024 * 1024 * 1024 * 1024 * 1024; // 1024 TB
      expect(formatBytes(aboveTB), equals('1024 TB'));
    });

    // Negative values
    test('should format -512 as "-512 B"', () {
      expect(formatBytes(-512), equals('-512 B'));
    });

    test('should format -1024 as "-1 KB"', () {
      expect(formatBytes(-1024), equals('-1 KB'));
    });

    test('should format -1536 as "-1.5 KB"', () {
      expect(formatBytes(-1536), equals('-1.5 KB'));
    });

    test('should format -2048 as "-2 KB"', () {
      expect(formatBytes(-2048), equals('-2 KB'));
    });

    test('should format negative MB', () {
      expect(formatBytes(-1572864), equals('-1.5 MB'));
    });

    test('should format negative GB', () {
      expect(formatBytes(-1610612736), equals('-1.5 GB'));
    });

    // Decimal trimming
    test('should trim trailing .00', () {
      expect(formatBytes(1024), equals('1 KB')); // 1.00 -> 1
    });

    test('should trim trailing .0 but keep meaningful decimals', () {
      expect(formatBytes(1024 * 1024 + 512 * 1024), equals('1.5 MB')); // 1.50 -> 1.5
    });

    // Large values
    test('should handle large values gracefully', () {
      final large = 1024 * 1024 * 1024 * 1024 * 1024; // 1 PB = 1024 TB
      expect(formatBytes(large), equals('1024 TB'));
    });

    test('should handle max int', () {
      // Max int scaled - int64 max is approximately 8388608 TB
      final result = formatBytes(9223372036854775807); // max int64
      expect(result, startsWith('8388608'));
    });
  });
}
