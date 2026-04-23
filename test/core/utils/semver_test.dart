import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions returns 0', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('differing major component - a less than b', () {
      expect(compareSemVer('1.2.3', '2.2.3'), isNegative);
    });

    test('differing major component - a greater than b', () {
      expect(compareSemVer('2.2.3', '1.2.3'), isPositive);
    });

    test('differing minor component - a less than b', () {
      expect(compareSemVer('1.1.3', '1.2.3'), isNegative);
    });

    test('differing minor component - a greater than b', () {
      expect(compareSemVer('1.3.3', '1.2.3'), isPositive);
    });

    test('differing patch component - a less than b', () {
      expect(compareSemVer('1.2.2', '1.2.3'), isNegative);
    });

    test('differing patch component - a greater than b', () {
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
    });

    test('numeric ordering (1.10.0 vs 1.2.0) - a greater than b', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
    });

    test('numeric ordering (1.10.0 vs 1.2.0) - a less than b when swapped', () {
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('short-form padding (1.2 vs 1.2.0) returns 0', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
    });

    test('short-form padding single component (1 vs 1.0.0) returns 0', () {
      expect(compareSemVer('1', '1.0.0'), equals(0));
    });

    test('extra-component truncation (1.2.3.4 vs 1.2.3) returns 0', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
    });

    test('malformed input throws FormatException', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('malformed input exception message contains offending input substring', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(
          isA<FormatException>().having((e) => e.message, 'message', contains('1.2.a')),
        ),
      );
    });

    test('empty string throws FormatException with original input', () {
      expect(
        () => compareSemVer('', '1.2.3'),
        throwsA(
          isA<FormatException>().having((e) => e.message, 'message', contains('')),
        ),
      );
    });

    test('whitespace-only string throws FormatException', () {
      expect(
        () => compareSemVer('   ', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
    });

    test('whitespace-only exception message contains original input', () {
      expect(
        () => compareSemVer('   ', '1.2.3'),
        throwsA(
          isA<FormatException>().having((e) => e.message, 'message', contains('   ')),
        ),
      );
    });
  });
}
