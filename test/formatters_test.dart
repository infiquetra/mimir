// Flutter test for formatBytes

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/src/utils/formatters.dart';

void main() {
  group('formatBytes', () {
    group('Bytes (B)', () {
      test('zero returns "0 B"', () {
        expect(formatBytes(0), equals('0 B'));
      });

      test('positive whole bytes', () {
        expect(formatBytes(1), equals('1 B'));
        expect(formatBytes(512), equals('512 B'));
        expect(formatBytes(1023), equals('1023 B'));
      });

      test('negative whole bytes', () {
        expect(formatBytes(-1), equals('-1 B'));
        expect(formatBytes(-512), equals('-512 B'));
        expect(formatBytes(-1023), equals('-1023 B'));
      });
    });

    group('B → KB transitions', () {
      test('exact threshold (1024)', () {
        expect(formatBytes(1024), equals('1 KB'));
        expect(formatBytes(-1024), equals('-1 KB'));
      });

      test('last byte before unit change (1023)', () {
        expect(formatBytes(1023), equals('1023 B'));
        expect(formatBytes(-1023), equals('-1023 B'));
      });

      test('first byte after threshold (1025)', () {
        expect(formatBytes(1025), equals('1 KB'));
        expect(formatBytes(-1025), equals('-1 KB'));
      });

      test('mid-range KB values', () {
        expect(formatBytes(1536), equals('1.5 KB'));
        expect(formatBytes(-1536), equals('-1.5 KB'));
        expect(formatBytes(2048), equals('2 KB'));
        expect(formatBytes(5120), equals('5 KB'));
      });
    });

    group('KB → MB transitions', () {
      test('exact threshold (1024^2 = 1048576)', () {
        expect(formatBytes(1048576), equals('1 MB'));
        expect(formatBytes(-1048576), equals('-1 MB'));
      });

      test('value just below MB boundary rounds and promotes', () {
        // 1048575 bytes = 1023.9990... KB, rounds to 1024 KB, promoted to 1 MB
        expect(formatBytes(1048575), equals('1 MB'));
        expect(formatBytes(-1048575), equals('-1 MB'));
      });

      test('first byte after threshold (1048577)', () {
        expect(formatBytes(1048577), equals('1 MB'));
        expect(formatBytes(-1048577), equals('-1 MB'));
      });

      test('mid-range MB values', () {
        expect(formatBytes(1572864), equals('1.5 MB')); // 1.5 * 1024 * 1024
        expect(formatBytes(-1572864), equals('-1.5 MB'));
        expect(formatBytes(2097152), equals('2 MB'));
      });
    });

    group('MB → GB transitions', () {
      test('exact threshold (1024^3 = 1073741824)', () {
        expect(formatBytes(1073741824), equals('1 GB'));
        expect(formatBytes(-1073741824), equals('-1 GB'));
      });

      test('value just below GB boundary rounds and promotes', () {
        // 1073741823 bytes = 1023.999... MB, rounds to 1024 MB, promoted to 1 GB
        expect(formatBytes(1073741823), equals('1 GB'));
        expect(formatBytes(-1073741823), equals('-1 GB'));
      });

      test('mid-range GB values', () {
        expect(formatBytes(1610612736), equals('1.5 GB')); // 1.5 * 1024^3
        expect(formatBytes(-1610612736), equals('-1.5 GB'));
      });
    });

    group('GB → TB transitions', () {
      test('exact threshold (1024^4 = 1099511627776)', () {
        expect(formatBytes(1099511627776), equals('1 TB'));
        expect(formatBytes(-1099511627776), equals('-1 TB'));
      });

      test('value just below TB boundary rounds and promotes', () {
        // 1099511627775 bytes = 1023.999... GB, rounds to 1024 GB, promoted to 1 TB
        expect(formatBytes(1099511627775), equals('1 TB'));
        expect(formatBytes(-1099511627775), equals('-1 TB'));
      });

      test('mid-range TB values', () {
        expect(formatBytes(1649267441664), equals('1.5 TB')); // 1.5 * 1024^4
        expect(formatBytes(-1649267441664), equals('-1.5 TB'));
      });
    });

    group('Precision and rounding behavior', () {
      test('trailing zeros are trimmed', () {
        expect(formatBytes(1024 * 1024 * 2), equals('2 MB'));
        expect(formatBytes(1024 * 2), equals('2 KB'));
      });

      test('decimal precision up to 2 places', () {
        // 1024 + 256 = 1280 bytes = 1.25 KB
        expect(formatBytes(1280), equals('1.25 KB'));
        // 1024 + 512 = 1536 bytes = 1.5 KB
        expect(formatBytes(1536), equals('1.5 KB'));
      });

      test('precision boundary - under 1 MB no rounding', () {
        // 1048576 - 1024 = 1047552 → 1023 KB exactly
        expect(formatBytes(1047552), equals('1023 KB'));
      });
    });

    group('Extreme values (TB clamping)', () {
      test('1024^5 bytes = 1024 TB', () {
        // 1024^5 = 1125899906842624
        expect(formatBytes(1125899906842624), equals('1024 TB'));
        expect(formatBytes(-1125899906842624), equals('-1024 TB'));
      });

      test('1024^6 bytes = 1048576 TB', () {
        // 1024^6 = 1152921504606846976
        expect(formatBytes(1152921504606846976), equals('1048576 TB'));
        expect(formatBytes(-1152921504606846976), equals('-1048576 TB'));
      });

      test('larger values stay in TB', () {
        // Arbitrary large value
        expect(formatBytes(2305843009213693952), equals('2097152 TB'));
      });
    });

    group('Edge cases', () {
      test('Int32 max value', () {
        // 2147483647 bytes = ~2.0 GB
        expect(formatBytes(2147483647), isA<String>());
        expect(formatBytes(2147483647), contains('GB'));
      });

      test('Int32 min value', () {
        // -2147483648 bytes = ~-2.0 GB
        expect(formatBytes(-2147483648), isA<String>());
        expect(formatBytes(-2147483648), startsWith('-'));
        expect(formatBytes(-2147483648), contains('GB'));
      });
    });
  });
}
