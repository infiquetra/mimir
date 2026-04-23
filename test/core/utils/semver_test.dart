import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions return 0', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('major difference return sign', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('minor difference return sign', () {
      expect(compareSemVer('1.1.0', '1.0.0'), isPositive);
      expect(compareSemVer('1.0.0', '1.1.0'), isNegative);
    });

    test('patch difference return sign', () {
      expect(compareSemVer('1.0.1', '1.0.0'), isPositive);
      expect(compareSemVer('1.0.0', '1.0.1'), isNegative);
    });

    test('numeric ordering (1.10.0 > 1.2.0)', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('short-form padding (1.2 == 1.2.0)', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
    });

    test('extra-component truncation (1.2.3.4 == 1.2.3)', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
    });

    test('malformed input throws FormatException', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('  ', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1..3', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('FormatException message contains offending input verbatim', () {
      final badInput = '1.2.a';
      expect(
        () => compareSemVer(badInput, '1.2.3'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(badInput))),
      );

      final badInput2 = '  ';
      expect(
        () => compareSemVer('1.2.3', badInput2),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(badInput2))),
      );
    });
  });
}
