import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions return 0', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('different major versions', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('different minor versions', () {
      expect(compareSemVer('1.3.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.3.0'), isNegative);
    });

    test('different patch versions', () {
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
    });

    test('numeric ordering (1.10.0 > 1.2.0)', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('short form padding (1.2 vs 1.2.0)', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
    });

    test('extra components ignored (1.2.3.4 vs 1.2.3)', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
    });

    test('throws FormatException on empty string', () {
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('throws FormatException on whitespace-only string', () {
      expect(() => compareSemVer('   ', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('throws FormatException on non-numeric component', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('FormatException message contains offending input', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(
          isA<FormatException>().having((e) => e.message, 'message', contains('1.2.a')),
        ),
      );
    });

    test('throws FormatException on version with missing component', () {
      expect(() => compareSemVer('1..3', '1.2.3'), throwsA(isA<FormatException>()));
    });
  });
}
