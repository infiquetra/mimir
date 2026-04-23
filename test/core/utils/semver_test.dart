import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('returns zero for equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('major difference returns negative', () {
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('major difference returns positive', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
    });

    test('minor difference returns negative', () {
      expect(compareSemVer('1.1.0', '1.2.0'), isNegative);
    });

    test('minor difference returns positive', () {
      expect(compareSemVer('1.2.0', '1.1.0'), isPositive);
    });

    test('patch difference returns negative', () {
      expect(compareSemVer('1.2.1', '1.2.2'), isNegative);
    });

    test('patch difference returns positive', () {
      expect(compareSemVer('1.2.2', '1.2.1'), isPositive);
    });

    test('numeric ordering: 1.10.0 > 1.2.0', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
    });

    test('short-form padding: 1.2 equals 1.2.0', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
    });

    test('extra-component truncation: 1.2.3.4 equals 1.2.3', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
    });

    test('throws FormatException for malformed input', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('FormatException message contains the offending input', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(
          isA<FormatException>().having((e) => e.message, 'message', contains('1.2.a')),
        ),
      );
    });

    test('throws FormatException for empty string', () {
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('throws FormatException for whitespace-only string', () {
      expect(() => compareSemVer('   ', '1.2.3'), throwsA(isA<FormatException>()));
    });
  });
}
