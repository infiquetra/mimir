import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatter.dart';

void main() {
  group('formatBytes', () {
    test('should format 0 bytes correctly', () {
      expect(formatBytes(0), '0 B');
    });

    test('should format 1 byte correctly', () {
      expect(formatBytes(1), '1 B');
    });

    test('should format bytes less than 1024 correctly', () {
      expect(formatBytes(1023), '1023 B');
    });

    test('should format exactly 1024 bytes (1 KiB) correctly', () {
      expect(formatBytes(1024), '1.00 KiB');
    });

    test('should format exactly 1048576 bytes (1 MiB) correctly', () {
      expect(formatBytes(1048576), '1.00 MiB');
    });

    test('should format exactly 1073741824 bytes (1 GiB) correctly', () {
      expect(formatBytes(1073741824), '1.00 GiB');
    });

    test('should format exactly 1099511627776 bytes (1 TiB) correctly', () {
      expect(formatBytes(1099511627776), '1.00 TiB');
    });

    test('should format values with decimals correctly', () {
      expect(formatBytes(1536), '1.50 KiB'); // 1.5 KiB
      expect(formatBytes(2097152), '2.00 MiB'); // 2 MiB
    });

    test('should throw ArgumentError for negative values', () {
      expect(() => formatBytes(-1), throwsArgumentError);
    });

    // Boundary tests for rounding edge cases
    test('should handle boundary rounding correctly', () {
      // Value just below 1 KiB that rounds up to 1024.00 should promote to 1.00 KiB
      expect(formatBytes(1048575), '1.00 MiB'); 
      
      // Value just below 1 MiB that rounds up to 1024.00 should promote to 1.00 MiB
      expect(formatBytes(1073740799), '1.00 GiB');
      
      // Value just below 1 GiB that rounds up to 1024.00 should promote to 1.00 GiB
      expect(formatBytes(1099510590463), '1.00 TiB');
    });

    // Test for values just below the promotion threshold
    test('should not promote when value does not round up to 1024.00', () {
      // 1047552 bytes = 1023.00 KiB exactly (should not promote)
      expect(formatBytes(1047552), '1023.00 KiB');
    });

    // Test extended unit ranges
    test('should handle values beyond terabytes', () {
      // Using smaller values for testing to avoid potential integer overflow
      // 2^50 = 1125899906842624 = 1 PiB
      expect(formatBytes(1125899906842624), '1.00 PiB');
    });
  });
}
