import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    // Equal versions
    test('returns 0 for equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
      expect(compareSemVer('0.0.0', '0.0.0'), equals(0));
      expect(compareSemVer('10.20.30', '10.20.30'), equals(0));
    });

    // Major difference
    test('returns negative when a has smaller major version', () {
      expect(compareSemVer('1.2.3', '2.0.0'), isNegative);
    });

    test('returns positive when a has larger major version', () {
      expect(compareSemVer('2.0.0', '1.2.3'), isPositive);
    });

    // Minor difference
    test('returns negative when a has smaller minor version', () {
      expect(compareSemVer('1.1.3', '1.2.0'), isNegative);
    });

    test('returns positive when a has larger minor version', () {
      expect(compareSemVer('1.2.0', '1.1.3'), isPositive);
    });

    // Patch difference
    test('returns negative when a has smaller patch version', () {
      expect(compareSemVer('1.2.2', '1.2.3'), isNegative);
    });

    test('returns positive when a has larger patch version', () {
      expect(compareSemVer('1.2.3', '1.2.2'), isPositive);
    });

    // Numeric ordering (not lexicographic)
    test('compares 1.10.0 > 1.2.0 numerically', () {
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
    });

    test('compares 1.99.99 < 2.0.0 numerically', () {
      expect(compareSemVer('1.99.99', '2.0.0'), isNegative);
      expect(compareSemVer('2.0.0', '1.99.99'), isPositive);
    });

    // Short-form padding
    test('treats 1.2 as 1.2.0', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
    });

    test('treats 1.2 < 1.2.1 when padded', () {
      expect(compareSemVer('1.2', '1.2.1'), isNegative);
      expect(compareSemVer('1.2.1', '1.2'), isPositive);
    });

    // Extra-component truncation
    test('ignores extra components beyond patch', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3.999', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3.4.5', '1.2.3'), equals(0));
    });

    // Malformed input: non-numeric component
    test('throws FormatException for non-numeric component', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('FormatException message contains offending input for non-numeric', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('1.2.a'))));
    });

    test('throws FormatException for letters in component', () {
      expect(() => compareSemVer('abc', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('throws FormatException for mixed alphanumeric', () {
      expect(() => compareSemVer('1.2a.3', '1.2.3'), throwsA(isA<FormatException>()));
    });

    // Malformed input: empty string
    test('throws FormatException for empty string', () {
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('FormatException message contains empty string', () {
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('got ""'))));
    });

    // Malformed input: whitespace-only string
    test('throws FormatException for whitespace-only string', () {
      expect(() => compareSemVer('   ', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('FormatException message contains whitespace string', () {
      expect(() => compareSemVer('   ', '1.2.3'), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('   '))));
    });

    // Signed components (should be rejected)
    test('throws FormatException for signed negative component', () {
      expect(() => compareSemVer('-1.2.3', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('throws FormatException for signed positive component', () {
      expect(() => compareSemVer('+1.2.3', '1.2.3'), throwsA(isA<FormatException>()));
    });

    // Edge cases
    test('handles zero components correctly', () {
      expect(compareSemVer('0.0.0', '0.0.0'), equals(0));
      expect(compareSemVer('0.0.0', '0.0.1'), isNegative);
    });

    test('handles large version numbers', () {
      expect(compareSemVer('999.999.999', '999.999.999'), equals(0));
      expect(compareSemVer('999.999.999', '1000.0.0'), isNegative);
    });
  });
}
