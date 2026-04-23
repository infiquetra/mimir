import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions returns 0', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.0', '1.2'), equals(0));
      expect(compareSemVer('1.2.3', '1.2.3.4'), equals(0));
    });

    test('major version difference uses sign assertion', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('minor version difference uses sign assertion', () {
      expect(compareSemVer('1.2.0', '1.1.0'), isPositive);
      expect(compareSemVer('1.1.0', '1.2.0'), isNegative);
    });

    test('patch version difference uses sign assertion', () {
      expect(compareSemVer('1.2.3', '1.2.2'), isPositive);
      expect(compareSemVer('1.2.2', '1.2.3'), isNegative);
    });

    test('numeric ordering not lexicographic', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('short-form version padding with zero', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1.2.0', '1.2'), equals(0));
    });

    test('extra trailing components ignored', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3', '1.2.3.4'), equals(0));
    });

    test('malformed input throws FormatException (type assertion)', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer(' ', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('malformed input exception message contains offending input substring', () {
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
  });
}