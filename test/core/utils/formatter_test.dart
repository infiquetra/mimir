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

    test('should format exactly 1024 bytes (1 KB) correctly', () {
      expect(formatBytes(1024), '1.00 KB');
    });

    test('should format exactly 1048576 bytes (1 MB) correctly', () {
      expect(formatBytes(1048576), '1.00 MB');
    });

    test('should format exactly 1073741824 bytes (1 GB) correctly', () {
      expect(formatBytes(1073741824), '1.00 GB');
    });

    test('should format exactly 1099511627776 bytes (1 TB) correctly', () {
      expect(formatBytes(1099511627776), '1.00 TB');
    });

    test('should format values with decimals correctly', () {
      expect(formatBytes(1536), '1.50 KB'); // 1.5 KB
      expect(formatBytes(2097152), '2.00 MB'); // 2 MB
    });

    test('should throw ArgumentError for negative values', () {
      expect(() => formatBytes(-1), throwsArgumentError);
    });
  });
}