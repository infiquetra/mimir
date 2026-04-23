import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('compareSemVer returns 0 for equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('compareSemVer compares major versions numerically', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('compareSemVer compares minor versions numerically', () {
      expect(compareSemVer('1.3.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.3.0'), isNegative);
    });

    test('compareSemVer compares patch versions numerically', () {
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
    });

    test('compareSemVer compares numerically not lexicographically', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('compareSemVer pads missing components with zero', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
    });

    test('compareSemVer ignores trailing components beyond patch', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3', '1.2.3.5'), equals(0));
    });

    test('compareSemVer throws FormatException for malformed input with empty string', () {
      expect(
        () => compareSemVer('', '1.2.3'),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('Empty string input'))
            .having((e) => e.message, 'message', contains('""'))),
      );
    });

    test('compareSemVer throws FormatException for malformed input with empty component', () {
      expect(
        () => compareSemVer('1..3', '1.2.3'),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('Empty component'))
            .having((e) => e.message, 'message', contains('1..3'))),
      );
    });

    test('compareSemVer throws FormatException for malformed input with non-numeric component', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('Non-numeric component'))
            .having((e) => e.message, 'message', contains('1.2.a'))),
      );
      
      expect(
        () => compareSemVer('1.2.3', '1.2.a'),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('Non-numeric component'))
            .having((e) => e.message, 'message', contains('1.2.a'))),
      );
    });

    test('compareSemVer throws FormatException for negative components', () {
      expect(
        () => compareSemVer('-1.2.3', '1.2.3'),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('Negative component'))
            .having((e) => e.message, 'message', contains('-1.2.3'))),
      );
      
      expect(
        () => compareSemVer('1.-2.3', '1.2.3'),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('Negative component'))
            .having((e) => e.message, 'message', contains('1.-2.3'))),
      );
    });
  });
}