// Flutter test for formatBytes

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/src/utils/formatters.dart';

void main() {
  // Helper to reduce test duplication
  void expectFormat(int input, String expected, {bool? isNegative}) {
    expect(formatBytes(input), equals(expected));
    if (isNegative != null) {
      if (isNegative) {
        expect(expected.startsWith('-'), isTrue, reason: 'Expected $expected to start with -');
      } else {
        expect(expected.startsWith('-'), isFalse, reason: 'Expected $expected not to start with -');
      }
    }
  }

  // Helper for table-driven tests
  void expectFormats(Map<int, String> cases) {
    cases.forEach(expectFormat);
  }

  group('formatBytes', () {
    group('Bytes (B)', () {
      test('zero returns "0 B"', () {
        expect(formatBytes(0), equals('0 B'));
      });

      test('positive whole bytes', () {
        expectFormats(const {
          1: '1 B',
          512: '512 B',
          1023: '1023 B',
        });
      });

      test('negative whole bytes', () {
        expectFormats(const {
          -1: '-1 B',
          -512: '-512 B',
          -1023: '-1023 B',
        });
      });
    });

    group('B → KB transitions', () {
      const Map<int, String> thresholdCases = {
        1024: '1 KB',
        -1024: '-1 KB',
      };
      const Map<int, String> justBelowCases = {
        1023: '1023 B',
        -1023: '-1023 B',
      };
      const Map<int, String> justAfterCases = {
        1025: '1 KB',
        -1025: '-1 KB',
      };
      const Map<int, String> midRangeCases = {
        1536: '1.5 KB',
        -1536: '-1.5 KB',
        2048: '2 KB',
        5120: '5 KB',
      };

      test('exact threshold (1024)', () => expectFormats(thresholdCases));
      test('last byte before unit change (1023)', () => expectFormats(justBelowCases));
      test('first byte after threshold (1025)', () => expectFormats(justAfterCases));
      test('mid-range KB values', () => expectFormats(midRangeCases));
    });

    group('KB → MB transitions', () {
      const int mbThreshold = 1024 * 1024;
      const Map<int, String> thresholdCases = {
        mbThreshold: '1 MB',
        -mbThreshold: '-1 MB',
      };
      const Map<int, String> justBelowCases = {
        // 1048575 bytes = 1023.9990... KB, rounds to 1024 KB, promoted to 1 MB
        1048575: '1 MB',
        -1048575: '-1 MB',
      };
      const Map<int, String> justAfterCases = {
        mbThreshold + 1: '1 MB',
        -(mbThreshold + 1): '-1 MB',
      };
      const Map<int, String> midRangeCases = {
        // 1.5 * 1024 * 1024 = 1572864
        1572864: '1.5 MB',
        -1572864: '-1.5 MB',
        mbThreshold * 2: '2 MB',
      };

      test('exact threshold (1048576)', () => expectFormats(thresholdCases));
      test('value just below MB boundary rounds and promotes', () => expectFormats(justBelowCases));
      test('first byte after threshold (1048577)', () => expectFormats(justAfterCases));
      test('mid-range MB values', () => expectFormats(midRangeCases));
    });

    group('MB → GB transitions', () {
      const int gbThreshold = 1024 * 1024 * 1024;
      const Map<int, String> thresholdCases = {
        gbThreshold: '1 GB',
        -gbThreshold: '-1 GB',
      };
      const Map<int, String> justBelowCases = {
        // 1073741823 bytes = 1023.999... MB, rounds to 1024 MB, promoted to 1 GB
        1073741823: '1 GB',
        -1073741823: '-1 GB',
      };
      // 1.5 * 1024^3 = 1610612736
      const Map<int, String> midRangeCases = {
        1610612736: '1.5 GB',
        -1610612736: '-1.5 GB',
      };

      test('exact threshold (1073741824)', () => expectFormats(thresholdCases));
      test('value just below GB boundary rounds and promotes', () => expectFormats(justBelowCases));
      test('mid-range GB values', () => expectFormats(midRangeCases));
    });

    group('GB → TB transitions', () {
      const int tbThreshold = 1024 * 1024 * 1024 * 1024; // 1099511627776
      const int mbValue = 1024 * 1024 * 1024; // For 1.5* below
      const Map<int, String> thresholdCases = {
        tbThreshold: '1 TB',
        -tbThreshold: '-1 TB',
      };
      const Map<int, String> justBelowCases = {
        // 1099511627775 bytes = 1023.999... GB, rounds to 1024 GB, promoted to 1 TB
        1099511627775: '1 TB',
        -1099511627775: '-1 TB',
      };
      // 1.5 * 1024^4 = 1649267441664
      const Map<int, String> midRangeCases = {
        1649267441664: '1.5 TB',
        -1649267441664: '-1.5 TB',
      };

      test('exact threshold (1099511627776)', () => expectFormats(thresholdCases));
      test('value just below TB boundary rounds and promotes', () => expectFormats(justBelowCases));
      test('mid-range TB values', () => expectFormats(midRangeCases));
    });

    group('Precision and rounding behavior', () {
      const Map<int, String> trailingZeroCases = {
        // 1024 * 1024 * 2 = 2097152 = 2 MB
        2097152: '2 MB',
        // 1024 * 2 = 2048 = 2 KB
        2048: '2 KB',
      };
      const Map<int, String> decimalCases = {
        // 1024 + 256 = 1280 bytes = 1.25 KB
        1280: '1.25 KB',
        // 1024 + 512 = 1536 bytes = 1.5 KB
        1536: '1.5 KB',
      };

      test('trailing zeros are trimmed', () => expectFormats(trailingZeroCases));
      test('decimal precision up to 2 places', () => expectFormats(decimalCases));

      test('precision boundary - under 1 MB no rounding', () {
        // 1048576 - 1024 = 1047552 → 1023 KB exactly
        expect(formatBytes(1047552), equals('1023 KB'));
      });
    });

    group('Extreme values (TB clamping)', () {
      // 1024^5 = 1125899906842624
      const Map<int, String> extremeCases = {
        1125899906842624: '1024 TB',
        -1125899906842624: '-1024 TB',
        // 1024^6 = 1152921504606846976
        1152921504606846976: '1048576 TB',
        -1152921504606846976: '-1048576 TB',
        // Arbitrary large value
        2305843009213693952: '2097152 TB',
      };

      test('extreme large values stay in TB', () => expectFormats(extremeCases));
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
