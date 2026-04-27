import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('returns zero for equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('returns positive when major version is greater', () {
      expect(compareSemVer('2.0.0', '1.99.99'), isPositive);
    });

    test('returns positive when minor version is greater numerically', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
    });

    test('returns negative when patch version is lower', () {
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
    });

    test('pads missing components with zero', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
    });

    test('ignores extra trailing components beyond patch', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
    });

    test('throws FormatException for malformed input', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
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
    });

    test('throws FormatException for empty and whitespace-only input', () {
      // Empty string
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

      // Whitespace-only — verify original input is preserved verbatim
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
