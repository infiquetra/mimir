import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions returns 0', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('major difference - returns positive when a > b', () {
      expect(compareSemVer('2.0.0', '1.99.99'), isPositive);
    });

    test('major difference - returns negative when a < b', () {
      expect(compareSemVer('1.99.99', '2.0.0'), isNegative);
    });

    test('minor difference - returns positive when a > b', () {
      expect(compareSemVer('1.3.0', '1.2.5'), isPositive);
    });

    test('minor difference - returns negative when a < b', () {
      expect(compareSemVer('1.1.5', '1.2.0'), isNegative);
    });

    test('patch difference - returns positive when a > b', () {
      expect(compareSemVer('1.2.3', '1.2.2'), isPositive);
    });

    test('patch difference - returns negative when a < b', () {
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
    });

    test('numeric ordering - 1.10.0 is greater than 1.2.0', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
    });

    test('numeric ordering - 1.2.0 is less than 1.10.0', () {
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('short-form padding - 1.2 equals 1.2.0', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
    });

    test('short-form padding - 1.0 equals 1', () {
      expect(compareSemVer('1.0', '1'), equals(0));
    });

    test('extra-component truncation - 1.2.3.4 equals 1.2.3', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
    });

    test('extra-component truncation - trailing components ignored', () {
      expect(compareSemVer('1.2.3.4.5.6', '1.2.3.7'), equals(0));
    });

    test('malformed input with non-numeric component throws FormatException', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
    });

    test('malformed input with non-numeric component includes offending input in message', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('1.2.a'),
        )),
      );
    });

    test('malformed input - empty string throws FormatException', () {
      expect(
        () => compareSemVer('', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
    });

    test('malformed input - whitespace-only string throws FormatException', () {
      expect(
        () => compareSemVer('   ', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
    });

    test('malformed input - empty component throws FormatException', () {
      expect(
        () => compareSemVer('1..2', '1.0.0'),
        throwsA(isA<FormatException>()),
      );
    });

    test('malformed input - second argument with non-numeric throws FormatException', () {
      expect(
        () => compareSemVer('1.2.3', '1.x.5'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('1.x.5'),
        )),
      );
    });
  });
}
