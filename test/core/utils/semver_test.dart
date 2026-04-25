import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions return 0', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('differing major component returns negative when a < b', () {
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('differing major component returns positive when a > b', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
    });

    test('differing minor component returns negative when a < b', () {
      expect(compareSemVer('1.1.0', '1.2.0'), isNegative);
    });

    test('differing minor component returns positive when a > b', () {
      expect(compareSemVer('1.2.0', '1.1.0'), isPositive);
    });

    test('differing patch component returns negative when a < b', () {
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
    });

    test('differing patch component returns positive when a > b', () {
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
    });

    test('1.10.0 > 1.2.0 (numeric not lexicographic)', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
    });

    test('1.2.0 < 1.10.0 (numeric not lexicographic)', () {
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('short form pads with zero', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
    });

    test('extra components are truncated', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
    });

    test('malformed input throws FormatException', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('malformed input message contains offending argument', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('1.2.a'))),
      );
    });

    test('empty string throws FormatException', () {
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('whitespace-only string throws FormatException', () {
      expect(() => compareSemVer('   ', '1.2.3'), throwsA(isA<FormatException>()));
    });
  });
}
