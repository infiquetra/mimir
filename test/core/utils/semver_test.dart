import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('returns 0 for equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
      expect(compareSemVer('0.0.0', '0.0.0'), equals(0));
      expect(compareSemVer('10.20.30', '10.20.30'), equals(0));
    });

    test('returns positive when major version is greater', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
    });

    test('returns negative when major version is smaller', () {
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('returns positive when minor version is greater', () {
      expect(compareSemVer('1.2.0', '1.1.0'), isPositive);
    });

    test('returns negative when minor version is smaller', () {
      expect(compareSemVer('1.1.0', '1.2.0'), isNegative);
    });

    test('returns positive when patch version is greater', () {
      expect(compareSemVer('1.2.3', '1.2.2'), isPositive);
    });

    test('returns negative when patch version is smaller', () {
      expect(compareSemVer('1.2.2', '1.2.3'), isNegative);
    });

    test('compares numeric components numerically instead of lexicographically',
        () {
      // 1.10.0 should be greater than 1.2.0 (numeric comparison)
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      // 1.2.0 should be less than 1.10.0
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('treats short versions as zero-padded', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
      expect(compareSemVer('1.2', '1.2.1'), isNegative);
    });

    test('ignores extra trailing components after patch', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3.4.5', '1.2.3'), equals(0));
    });

    test('throws FormatException for non-numeric input', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'),
          throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', '1.2.a'),
          throwsA(isA<FormatException>()));
    });

    test('includes non-numeric offending input in FormatException message', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(
          predicate((e) => e is FormatException && e.message.contains('1.2.a')),
        ),
      );
    });

    test('throws FormatException for empty input', () {
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('includes empty offending input in FormatException message', () {
      expect(
        () => compareSemVer('', '1.2.3'),
        throwsA(
          predicate((e) => e is FormatException && e.message.contains('')),
        ),
      );
    });

    test('throws FormatException for whitespace-only input', () {
      expect(
          () => compareSemVer('   ', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('includes whitespace-only offending input in FormatException message',
        () {
      expect(
        () => compareSemVer('   ', '1.2.3'),
        throwsA(
          predicate((e) => e is FormatException && e.message.contains('   ')),
        ),
      );
    });

    test('throws FormatException for version with empty component', () {
      expect(() => compareSemVer('1..3', '1.2.3'),
          throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.', '1.2.3'),
          throwsA(isA<FormatException>()));
    });

    test('handles negative comparison correctly', () {
      expect(compareSemVer('1.2.3', '2.0.0'), isNegative);
    });

    test('handles large version numbers', () {
      expect(compareSemVer('2.0.0', '1.99.99'), isPositive);
      expect(compareSemVer('999.999.999', '1.1.1'), isPositive);
    });
  });
}
