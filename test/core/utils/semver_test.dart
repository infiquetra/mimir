import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('returns zero for equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('compares major versions numerically', () {
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
    });

    test('compares minor versions numerically', () {
      expect(compareSemVer('1.1.0', '1.2.0'), isNegative);
      expect(compareSemVer('1.3.0', '1.2.0'), isPositive);
    });

    test('compares patch versions numerically', () {
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
      expect(compareSemVer('1.2.5', '1.2.4'), isPositive);
    });

    test('compares numeric components instead of lexicographic strings', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
    });

    test('pads missing components with zero', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
      expect(compareSemVer('1.2', '1.2.1'), isNegative);
    });

    test('ignores components beyond patch', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3.999', '1.2.3'), equals(0));
    });

    test('throws FormatException for malformed input', () {
      // Non-numeric component
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
      // Empty string
      expect(
        () => compareSemVer('', '1.0.0'),
        throwsA(isA<FormatException>()),
      );
      // Whitespace-only string
      expect(
        () => compareSemVer('   ', '1.0.0'),
        throwsA(isA<FormatException>()),
      );
      // Malformed in second argument
      expect(
        () => compareSemVer('1.0.0', 'abc'),
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
  });
}
