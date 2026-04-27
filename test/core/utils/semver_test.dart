import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('returns zero for equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('compares major components numerically', () {
      expect(compareSemVer('2.0.0', '1.99.99'), isPositive);
      expect(compareSemVer('1.99.99', '2.0.0'), isNegative);
    });

    test('compares minor components numerically', () {
      expect(compareSemVer('1.3.0', '1.2.99'), isPositive);
      expect(compareSemVer('1.2.99', '1.3.0'), isNegative);
    });

    test('compares patch components numerically', () {
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
    });

    test('orders numeric components instead of lexicographic strings', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
    });

    test('pads short versions with zero components', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
    });

    test('ignores extra trailing components after patch', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
    });

    test('throws FormatException for malformed input', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for empty string input', () {
      expect(
        () => compareSemVer('', '1.2.3'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Malformed semantic version: '),
        )),
      );
    });

    test('throws FormatException for whitespace-only input', () {
      expect(
        () => compareSemVer('   ', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
    });

    test('includes offending input in FormatException message', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('1.2.a'),
        )),
      );
    });
  });
}
