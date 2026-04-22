import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('humanizeBytes', () {
    test('should return 0 B for zero bytes', () {
      expect(humanizeBytes(0), '0 B');
    });

    test('should handle bytes without scaling', () {
      expect(humanizeBytes(512), '512 B');
      expect(humanizeBytes(1023), '1023 B');
    });

    test('should handle KB boundary correctly', () {
      expect(humanizeBytes(1024), '1 KB');
      expect(humanizeBytes(1025), '1 KB');
      expect(humanizeBytes(1536), '1.5 KB');
      expect(humanizeBytes(2048), '2 KB');
    });

    test('should handle MB boundary correctly', () {
      expect(humanizeBytes(1048576), '1 MB'); // 1024 * 1024
      expect(humanizeBytes(1572864), '1.5 MB'); // 1024 * 1024 * 1.5
    });

    test('should handle GB boundary correctly', () {
      expect(humanizeBytes(1073741824), '1 GB'); // 1024 * 1024 * 1024
    });

    test('should handle negative values correctly', () {
      expect(humanizeBytes(-512), '-512 B');
      expect(humanizeBytes(-1024), '-1 KB');
      expect(humanizeBytes(-2048), '-2 KB');
      expect(humanizeBytes(-1536), '-1.5 KB');
    });

    test('should handle values above TB correctly', () {
      // 1024^5 = 1125899906842624 bytes = 1024 TB
      expect(humanizeBytes(1125899906842624), '1024 TB');
      // 2048 TB = 2 * 1024^5 bytes
      expect(humanizeBytes(2251799813685248), '2048 TB');
    });

    test('should trim trailing zeros correctly', () {
      // Ensure values that result in .00 are trimmed to whole numbers
      expect(humanizeBytes(1024), '1 KB');
      expect(humanizeBytes(2048), '2 KB');
      
      // Ensure values with single decimal digit are formatted correctly
      expect(humanizeBytes(1536), '1.5 KB');
    });
  });
}