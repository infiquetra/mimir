import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('returns zero for equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('compares differing major components numerically', () {
      // 2.0.0 > 1.99.99
      expect(compareSemVer('2.0.0', '1.99.99'), isPositive);
      // 1.0.0 < 2.0.0
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('compares differing minor components numerically', () {
      // 1.3.0 > 1.2.99
      expect(compareSemVer('1.3.0', '1.2.99'), isPositive);
      // 1.2.0 < 1.3.0
      expect(compareSemVer('1.2.0', '1.3.0'), isNegative);
    });

    test('compares differing patch components numerically', () {
      // 1.2.3 < 1.2.4
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
      // 1.2.4 > 1.2.3
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
    });

    test('orders numeric components numerically instead of lexicographically', () {
      // 1.10.0 > 1.2.0 (10 > 2 numerically, not lexicographic "10" < "2")
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
    });

    test('pads short versions with zero components', () {
      // 1.2 is treated as 1.2.0
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
    });

    test('ignores components after patch', () {
      // 1.2.3.4 is treated as 1.2.3
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
    });

    test('throws FormatException for malformed input', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', '1.2.a'), throwsA(isA<FormatException>()));
    });

    test('includes offending input in FormatException message', () {
      try {
        compareSemVer('1.2.a', '1.2.3');
        fail('Expected FormatException was not thrown');
      } on FormatException catch (e) {
        expect(e.message, contains('1.2.a'));
      }
    });

    test('throws FormatException for whitespace-only input', () {
      expect(() => compareSemVer('   ', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('throws FormatException for empty input', () {
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
    });
  });
}
