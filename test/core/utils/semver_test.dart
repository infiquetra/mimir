import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('returns zero for equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('compares major component numerically', () {
      expect(compareSemVer('2.0.0', '1.99.99'), isPositive);
      expect(compareSemVer('1.99.99', '2.0.0'), isNegative);
    });

    test('compares minor component numerically', () {
      expect(compareSemVer('1.3.0', '1.2.99'), isPositive);
      expect(compareSemVer('1.2.99', '1.3.0'), isNegative);
    });

    test('compares patch component numerically', () {
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
    });

    test('uses numeric ordering instead of lexicographic ordering', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('pads short versions with zero components', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
      expect(compareSemVer('2.0', '1.999.999'), isPositive);
    });

    test('ignores extra trailing components beyond patch', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3.4.5.6', '1.2.3'), equals(0));
    });

    test('throws FormatException for malformed input', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', '1.x.3'), throwsA(isA<FormatException>()));
    });

    test('includes offending input in FormatException message', () {
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
        () => compareSemVer('1.2.3', '1.x.3'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('1.x.3'),
          ),
        ),
      );
    });

    test('throws FormatException for empty input', () {
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', ''), throwsA(isA<FormatException>()));
    });

    test('throws FormatException for whitespace-only input and preserves it in the message', () {
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

    test('handles zero values correctly', () {
      expect(compareSemVer('0.0.0', '0.0.0'), equals(0));
      expect(compareSemVer('0.1.0', '0.0.1'), isPositive);
    });

    test('handles large version numbers', () {
      expect(compareSemVer('999.999.999', '999.999.998'), isPositive);
      expect(compareSemVer('1000.0.0', '999.999.999'), isPositive);
    });
  });
}
