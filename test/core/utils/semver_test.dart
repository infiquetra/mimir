import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('returns 0 for equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('returns positive/negative when major differs', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('returns positive/negative when minor differs', () {
      expect(compareSemVer('1.2.0', '1.1.0'), isPositive);
      expect(compareSemVer('1.1.0', '1.2.0'), isNegative);
    });

    test('returns positive/negative when patch differs', () {
      expect(compareSemVer('1.2.3', '1.2.2'), isPositive);
      expect(compareSemVer('1.2.2', '1.2.3'), isNegative);
    });

    test('compares numerically, not lexicographically', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('pads short versions with zero', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
    });

    test('ignores trailing components after patch', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3', '1.2.3.4'), equals(0));
    });

    test('throws FormatException for malformed input', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'),
          throwsA(isA<FormatException>()));
      expect(() => compareSemVer('', '1.2.3'),
          throwsA(isA<FormatException>()));
      expect(() => compareSemVer(' ', '1.2.3'),
          throwsA(isA<FormatException>()));
    });

    test('includes offending input in FormatException message', () {
      expect(
          () => compareSemVer('1.2.a', '1.2.3'),
          throwsA(isA<FormatException>()
              .having((e) => e.message, 'message', contains('1.2.a'))));
      expect(
          () => compareSemVer('', '1.2.3'),
          throwsA(isA<FormatException>()
              .having((e) => e.message, 'message', contains('""'))));
    });
  });
}