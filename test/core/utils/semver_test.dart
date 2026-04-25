import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions returns equals(0)', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('major difference returns sign-only assertion', () {
      expect(compareSemVer('2.0.0', '1.99.99'), isPositive);
      expect(compareSemVer('1.99.99', '2.0.0'), isNegative);
    });

    test('minor difference returns sign-only assertion', () {
      expect(compareSemVer('1.2.0', '1.1.99'), isPositive);
      expect(compareSemVer('1.1.99', '1.2.0'), isNegative);
    });

    test('patch difference returns sign-only assertion', () {
      expect(compareSemVer('1.2.3', '1.2.2'), isPositive);
      expect(compareSemVer('1.2.2', '1.2.3'), isNegative);
    });

    test('numeric ordering uses sign-only assertion', () {
      // 1.10.0 > 1.2.0 because 10 > 2 (numeric comparison, not lexicographic)
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('short-form padding (1.2 vs 1.2.0) returns equals(0)', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1.2.0', '1.2'), equals(0));
    });

    test('short-form with only major', () {
      expect(compareSemVer('1', '1.0.0'), equals(0));
      expect(compareSemVer('2', '1.99.99'), isPositive);
    });

    test('extra-component truncation (1.2.3.4 vs 1.2.3) returns equals(0)', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3', '1.2.3.4'), equals(0));
    });

    test('extra components beyond patch are ignored in comparison', () {
      // 1.2.3.5 vs 1.2.3.4 - the 4th component should be ignored
      expect(compareSemVer('1.2.3.5', '1.2.3.4'), equals(0));
    });

    test('malformed input throws FormatException', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', 'bad'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', ''), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', '   '), throwsA(isA<FormatException>()));
    });

    test('malformed input error message contains offending substring', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('1.2.a'))),
      );
      expect(
        () => compareSemVer('1.2.3', 'bad'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('bad'))),
      );
    });
  });
}
