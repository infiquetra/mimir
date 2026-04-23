import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions returns zero', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('major difference returns sign-only result', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('minor difference returns sign-only result', () {
      expect(compareSemVer('1.2.0', '1.1.0'), isPositive);
      expect(compareSemVer('1.1.0', '1.2.0'), isNegative);
    });

    test('patch difference returns sign-only result', () {
      expect(compareSemVer('1.2.3', '1.2.2'), isPositive);
      expect(compareSemVer('1.2.2', '1.2.3'), isNegative);
    });

    test('compares numeric components, not lexicographic strings', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('pads short versions with zero patch', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1.2.0', '1.2'), equals(0));
    });

    test('ignores components beyond patch', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3', '1.2.3.4'), equals(0));
    });

    test('throws FormatException for empty input', () {
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', ''), throwsA(isA<FormatException>()));
    });

    test('throws FormatException for whitespace-only input', () {
      expect(() => compareSemVer('   ', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', '\t\n'), throwsA(isA<FormatException>()));
    });

    test('throws FormatException for non-numeric components', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', '1.b.3'), throwsA(isA<FormatException>()));
    });

    test('includes offending input in FormatException.message', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', contains('1.2.a')),
        ),
      );
      
      expect(
        () => compareSemVer('1.2.3', 'x.2.3'),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', contains('x.2.3')),
        ),
      );
    });
  });
}