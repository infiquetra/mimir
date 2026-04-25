import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions return zero', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('major difference returns positive when a > b', () {
      expect(compareSemVer('2.0.0', '1.99.99'), isPositive);
    });

    test('major difference returns negative when a < b', () {
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('minor difference returns positive when a > b', () {
      expect(compareSemVer('1.3.0', '1.2.0'), isPositive);
    });

    test('minor difference returns negative when a < b', () {
      expect(compareSemVer('1.2.0', '1.3.0'), isNegative);
    });

    test('patch difference returns positive when a > b', () {
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
    });

    test('patch difference returns negative when a < b', () {
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
    });

    test('numeric ordering: 1.10.0 > 1.2.0', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
    });

    test('short-form padding: 1.2 equals 1.2.0', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
    });

    test('single-component version: 1 equals 1.0.0', () {
      expect(compareSemVer('1', '1.0.0'), equals(0));
    });

    test('extra-component truncation: 1.2.3.4 equals 1.2.3', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
    });

    test('throws FormatException for non-numeric component', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
    });

    test('FormatException message includes the offending input verbatim', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('1.2.a'),
          ),
        ),
      );
    });

    test('throws FormatException for empty string', () {
      expect(
        () => compareSemVer('', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
    });

    test('FormatException message for empty string includes the input', () {
      expect(
        () => compareSemVer('', '1.2.3'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(''),
          ),
        ),
      );
    });

    test('throws FormatException for whitespace-only string', () {
      expect(
        () => compareSemVer('   ', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
    });

    test('FormatException message for whitespace-only includes the input', () {
      expect(
        () => compareSemVer('   ', '1.2.3'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('   '),
          ),
        ),
      );
    });
  });
}
