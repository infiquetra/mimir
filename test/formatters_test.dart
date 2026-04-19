// Flutter test for formatBytes

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/src/utils/formatters.dart';

void main() {
  // Helper to reduce test duplication
  void expectFormat(int input, String expected) {
    expect(formatBytes(input), equals(expected));
  }

  // Helper for both positive and negative cases
  void expectBoth(int input, String expected) {
    expectFormat(input, expected);
    // Negative version prepends '-'
    expectFormat(-input, '-$expected');
  }

  group('formatBytes', () {
    group('Bytes (B)', () {
      test('zero returns "0 B"', () {
        expect(formatBytes(0), equals('0 B'));
      });

      test('positive and negative whole bytes', () {
        expectBoth(1, '1 B');
        expectBoth(512, '512 B');
        expectBoth(1023, '1023 B');
      });
    });

    group('B → KiB transitions', () {
      test('exact threshold and boundaries', () {
        expectBoth(1024, '1 KiB');
        expectBoth(1023, '1023 B');
        expectBoth(1025, '1 KiB');
      });

      test('mid-range KiB values', () {
        expectBoth(1536, '1.5 KiB');
        expectBoth(2048, '2 KiB');
        expectBoth(5120, '5 KiB');
      });
      
      test('KiB values requiring hundredths precision', () {
        // 1034 bytes = 1.009765... KiB → rounds to 1.01 KiB
        expectBoth(1034, '1.01 KiB');
        // 1075 bytes = 1.049804... KiB → rounds to 1.05 KiB
        expectBoth(1075, '1.05 KiB');
        // 1076 bytes = 1.050781... KiB → rounds to 1.05 KiB
        expectBoth(1076, '1.05 KiB');
        // 1050 bytes = 1.025390... KiB → rounds to 1.03 KiB
        expectBoth(1050, '1.03 KiB');
        // 1025 bytes = 1.000976... KiB → rounds to 1 KiB
        expectBoth(1025, '1 KiB');
        // 1029 bytes = 1.004882... KiB → rounds to 1 KiB
        expectBoth(1029, '1 KiB');
        // 1030 bytes = 1.005859... KiB → rounds to 1.01 KiB
        expectBoth(1030, '1.01 KiB');
      });
    });

    group('KiB → MiB transitions', () {
      const int mbThreshold = 1024 * 1024;

      test('exact threshold and boundaries', () {
        expectBoth(mbThreshold, '1 MiB');
        expectBoth(1048575, '1 MiB');
        expectBoth(mbThreshold + 1, '1 MiB');
      });

      test('mid-range MiB values', () {
        // 1.5 * 1024 * 1024 = 1572864
        expectBoth(1572864, '1.5 MiB');
        expectBoth(mbThreshold * 2, '2 MiB');
      });

      test('MiB values requiring hundredths precision', () {
        // Testing that leading zero hundredths work at larger scales
        // 1.01 MiB = 1059061.76 bytes → test value that rounds to 1.01
        expectBoth(1059062, '1.01 MiB');
        // 1.05 MiB = 1101004.8 bytes → test value that rounds to 1.05
        expectBoth(1101005, '1.05 MiB');
      });
    });

    group('MiB → GiB transitions', () {
      const int gbThreshold = 1024 * 1024 * 1024;

      test('exact threshold and boundaries', () {
        expectBoth(gbThreshold, '1 GiB');
        expectBoth(1073741823, '1 GiB');
      });

      test('mid-range GiB values', () {
        // 1.5 * 1024^3 = 1610612736
        expectBoth(1610612736, '1.5 GiB');
      });

      test('GiB values requiring hundredths precision', () {
        // Testing precision at GiB scale
        expectBoth(1084578514, '1.01 GiB');
      });
    });

    group('GiB → TiB transitions', () {
      // 1 TiB = 1024^4 = 1099511627776
      const int tbThreshold = 1024 * 1024 * 1024 * 1024;

      test('exact threshold and boundaries', () {
        expectBoth(tbThreshold, '1 TiB');
        expectBoth(1099511627775, '1 TiB');
      });

      test('mid-range TiB values', () {
        // 1.5 * 1024^4 = 1649267441664
        expectBoth(1649267441664, '1.5 TiB');
      });
    });

    group('Precision and rounding behavior', () {
      test('trailing zeros are trimmed', () {
        expectBoth(2097152, '2 MiB');
        expectBoth(2048, '2 KiB');
      });

      test('decimal precision up to 2 places', () {
        expectBoth(1280, '1.25 KiB');
        expectBoth(1536, '1.5 KiB');
      });

      test('preserves leading zero in hundredths', () {
        // Critical regression tests for the _formatScaled bug
        // where values like 1.01 were rendered as 1.1
        expectBoth(1034, '1.01 KiB');
        expectBoth(1075, '1.05 KiB');
      });

      test('precision boundary - under 1 MiB no rounding', () {
        // 1048576 - 1024 = 1047552 → 1023 KiB exactly
        expect(formatBytes(1047552), equals('1023 KiB'));
      });
    });

    group('Extreme values (TiB clamping)', () {
      // Use values within JS safe integer range (2^53 - 1 = 9007199254740991)
      // for web portability. Values beyond this may lose precision on Flutter web.
      test('values within safe integer range', () {
        // 1024^5 = 1125899906842624 (within safe range)
        expectBoth(1125899906842624, '1024 TiB');
        // 1024^6 = 1152921504606846976 (close to but within safe range)
        expectBoth(1152921504606846976, '1048576 TiB');
      });

      // Note: Values above 2^53-1 may have precision issues on Flutter web due to
      // JavaScript's Number type limitations. Use BigInt in implementation if needed.
    });

    group('Edge cases', () {
      test('Int32 max value', () {
        // 2147483647 bytes = ~2.0 GiB
        expect(formatBytes(2147483647), isA<String>());
        expect(formatBytes(2147483647), contains('GiB'));
      });

      test('Int32 min value', () {
        // -2147483648 bytes = ~-2.0 GiB
        expect(formatBytes(-2147483648), isA<String>());
        expect(formatBytes(-2147483648), startsWith('-'));
        expect(formatBytes(-2147483648), contains('GiB'));
      });
    });
  });
}
