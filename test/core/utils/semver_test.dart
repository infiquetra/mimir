import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('returns 0 for equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('compares major differences', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('compares minor differences', () {
      expect(compareSemVer('1.2.0', '1.1.0'), isPositive);
      expect(compareSemVer('1.1.0', '1.2.0'), isNegative);
    });

    test('compares patch differences', () {
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
    });

    test('compares versions numerically', () {
      // 1.10.0 > 1.2.0
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('treats short-form versions as padded with zeros', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
      expect(compareSemVer('1.2.0', '1.2'), equals(0));
    });

    test('ignores extra components beyond patch', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3', '1.2.3.99'), equals(0));
    });

    test('throws FormatException for non-numeric components', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('1.2.a'))),
      );
    });

    test('throws FormatException for empty or whitespace strings', () {
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer(' ', '1.2.3'), throwsA(isA<FormatException>()));
      expect(
        () => compareSemVer('1.2.3', ''),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(''))),
      );
    });
  });
}
