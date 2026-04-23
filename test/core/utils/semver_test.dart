import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('Equal versions should return 0', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('Major version difference should return correct sign', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('Minor version difference should return correct sign', () {
      expect(compareSemVer('1.2.0', '1.1.0'), isPositive);
      expect(compareSemVer('1.1.0', '1.2.0'), isNegative);
    });

    test('Patch version difference should return correct sign', () {
      expect(compareSemVer('1.2.1', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.2.1'), isNegative);
    });

    test('Numeric ordering (1.10.0 > 1.2.0)', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('Short-form padding (1.2 == 1.2.0)', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
    });

    test('Extra-component truncation (1.2.3.4 == 1.2.3)', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
    });

    test('Malformed input should throw FormatException', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer(' ', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1..2', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('FormatException message should contain offending input', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('1.2.a'))),
      );
      expect(
        () => compareSemVer('1.2.3', 'b.2.3'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('b.2.3'))),
      );
    });
  });
}
