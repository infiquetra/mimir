import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('returns zero for equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
      expect(compareSemVer('0.0.0', '0.0.0'), equals(0));
      expect(compareSemVer('10.20.30', '10.20.30'), equals(0));
    });

    test('compares differing major components numerically', () {
      expect(compareSemVer('2.0.0', '1.99.99'), isPositive);
      expect(compareSemVer('1.99.99', '2.0.0'), isNegative);
    });

    test('compares differing minor components numerically', () {
      expect(compareSemVer('1.3.0', '1.2.99'), isPositive);
      expect(compareSemVer('1.2.99', '1.3.0'), isNegative);
    });

    test('compares differing patch components numerically', () {
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
    });

    test('compares numeric components instead of lexicographic order', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
      // Ensure numeric comparison, not lexicographic: '10' > '2'
      expect(compareSemVer('2.2.0', '10.1.0'), isNegative);
      expect(compareSemVer('10.1.0', '2.2.0'), isPositive);
    });

    test('pads short versions with zero components', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      // Semantics: '1' → [1,0,0], '1.2' → [1,2,0], '1.2.3' → [1,2,3]
      expect(compareSemVer('2', '1.9.9'), isPositive);
      expect(compareSemVer('2.1', '2.0.9'), isPositive);
    });

    test('ignores extra trailing components beyond patch', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3', '1.2.3.4'), equals(0));
      expect(compareSemVer('1.2.3.9', '1.2.3.9'), equals(0));
      // Extra components do not affect comparison
      expect(compareSemVer('1.2.3.100', '1.2.3'), equals(0));
    });

    test('throws FormatException for malformed input', () {
      // Non‑numeric component
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', '1.2.a'), throwsA(isA<FormatException>()));
      // Empty string
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
      // Purely whitespace string
      expect(() => compareSemVer('   ', '1.2.3'), throwsA(isA<FormatException>()));
      // Multiple malformed components
      expect(() => compareSemVer('a.b.c', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', 'a.b.c'), throwsA(isA<FormatException>()));
    });

    test('includes offending input in FormatException message', () {
      // Single malformed argument 'a' should appear in exception
      expect(
        () => compareSemVer('a', '1.2.3'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('a'),
        )),
      );
      // Malformed argument '1.2.a' appears
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('1.2.a'),
        )),
      );
      // Whitespace input appears
      expect(
        () => compareSemVer('   ', '1.2.3'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('   '),
        )),
      );
      // Second argument malformed
      expect(
        () => compareSemVer('1.2.3', 'b.c.d'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('b.c.d'),
        )),
      );
    });
  });
}