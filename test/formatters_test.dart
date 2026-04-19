import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/formatters.dart';

void main() {
  group('formatBytes', () {
    test('handles zero bytes', () {
      expect(formatBytes(0), '0 B');
    });

    test('handles single byte', () {
      expect(formatBytes(1), '1 B');
    });

    test('handles multiple bytes', () {
      expect(formatBytes(2), '2 B');
      expect(formatBytes(100), '100 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('converts to KB at boundary', () {
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(1536), '1.5 KB'); // 1.5 * 1024 = 1536
    });

    test('formats KB with proper decimal places', () {
      expect(formatBytes(1500), '1.46 KB'); // ~1.4648, rounded and trimmed
      expect(formatBytes(2048), '2 KB'); // Exact 2 KB
    });

    test('converts to MB at boundary', () {
      expect(formatBytes(1024 * 1024), '1 MB');
      expect(formatBytes((1024 * 1024 * 3) ~/ 2).toString().startsWith('1.5'), isTrue); // 1.5 MB
    });

    test('converts to GB at boundary', () {
      expect(formatBytes(1024 * 1024 * 1024), '1 GB');
    });

    test('converts to TB at boundary', () {
      expect(formatBytes(1024 * 1024 * 1024 * 1024), '1 TB');
    });

    test('handles values larger than TB', () {
      // Should continue scaling numerically within TB unit
      expect(formatBytes(1024 * 1024 * 1024 * 1024 * 2), '2 TB');
      expect(formatBytes(1024 * 1024 * 1024 * 1024 * 1024), '1024 TB');
    });

    test('trims trailing zeros properly', () {
      // Values that result in .00 should be trimmed to whole numbers
      expect(formatBytes(1024), '1 KB'); // Exactly 1 KB
      expect(formatBytes(2048), '2 KB'); // Exactly 2 KB
      
      // Values with significant decimals should keep them
      expect(formatBytes(1536), '1.5 KB'); // Exactly 1.5 KB
      
      // Values with insignificant trailing zeros should be trimmed
      expect(formatBytes(1075), '1.05 KB'); // ~1.0503 KB, should be 1.05 KB
    });

    test('handles exact boundary transitions', () {
      // Test boundaries for each unit transition
      expect(formatBytes(1023), '1023 B');
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(1024 * 1024 - 1), '1024 KB'); // 1048575 bytes = 1024 KB
      expect(formatBytes(1024 * 1024), '1 MB'); // 1048576 bytes = 1 MB
      expect(formatBytes(1024 * 1024 * 1024 - 1), '1024 MB'); // One byte less than 1 GB
      expect(formatBytes(1024 * 1024 * 1024), '1 GB'); // Exactly 1 GB
      expect(formatBytes(1024 * 1024 * 1024 * 1024 - 1), '1024 GB'); // One byte less than 1 TB
      expect(formatBytes(1024 * 1024 * 1024 * 1024), '1 TB'); // Exactly 1 TB
    });
    
    test('handles negative values correctly', () {
      expect(formatBytes(-1), '-1 B');
      expect(formatBytes(-1023), '-1023 B');
      expect(formatBytes(-1024), '-1 KB');
      expect(formatBytes(-1536), '-1.5 KB');
      expect(formatBytes(-2048), '-2 KB');
      expect(formatBytes(-1024 * 1024), '-1 MB');
      expect(formatBytes(-1024 * 1024 * 1024), '-1 GB');
      expect(formatBytes(-1024 * 1024 * 1024 * 1024), '-1 TB');
    });

    // Boundary test cases for verifying exact transition points
    test('boundary cases for accurate rounding', () {
      // Make sure values are displayed correctly at transitions
      expect(formatBytes(1023), '1023 B');
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(1024 * 1024 - 1), '1024 KB'); // 1048575 bytes = 1024 KB (just under 1 MB)
      expect(formatBytes(1024 * 1024), '1 MB'); // Exactly 1 MB
      expect(formatBytes(1024 * 1024 * 1024 - 1), '1024 MB'); // Just under 1 GB
      expect(formatBytes(1024 * 1024 * 1024), '1 GB'); // Exactly 1 GB
      expect(formatBytes(1024 * 1024 * 1024 * 1024 - 1), '1024 GB'); // Just under 1 TB
      expect(formatBytes(1024 * 1024 * 1024 * 1024), '1 TB'); // Exactly 1 TB
    });

    test('very large values stay expressed in TB', () {
      expect(formatBytes(1024 * 1024 * 1024 * 1024 * 1024), '1024 TB');
      expect(formatBytes(1024 * 1024 * 1024 * 1024 * 2048), '2048 TB');
    });
  });
}