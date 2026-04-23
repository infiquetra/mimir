import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions returns equals(0)', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('major difference - first version is smaller', () {
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('major difference - first version is larger', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
    });

    test('minor difference - first version is smaller', () {
      expect(compareSemVer('1.2.0', '1.5.0'), isNegative);
    });

    test('minor difference - first version is larger', () {
      expect(compareSemVer('1.5.0', '1.2.0'), isPositive);
    });

    test('patch difference - first version is smaller', () {
      expect(compareSemVer('1.2.3', '1.2.5'), isNegative);
    });

    test('patch difference - first version is larger', () {
      expect(compareSemVer('1.2.5', '1.2.3'), isPositive);
    });

    test('numeric ordering - 1.10.0 is greater than 1.2.0', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('short-form padding - 1.2 is treated as 1.2.0', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1.2.0', '1.2'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
    });

    test('extra-component truncation - 1.2.3.4 is treated as 1.2.3', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3', '1.2.3.4'), equals(0));
    });

    test('malformed input throws FormatException', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', '1.2.a'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', ''), throwsA(isA<FormatException>()));
      expect(
        () => compareSemVer('  ', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => compareSemVer('1.2.3', '  '),
        throwsA(isA<FormatException>()),
      );
    });

    test('malformed input message contains offending input substring', () {
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
      expect(
        () => compareSemVer('1.2.3', 'invalid'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('invalid'),
          ),
        ),
      );
      expect(
        () => compareSemVer('', '1.2.3'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('""'),
          ),
        ),
      );
    });
  });
}
