import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions returns 0', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('major differences', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('minor differences', () {
      expect(compareSemVer('1.2.0', '1.1.0'), isPositive);
      expect(compareSemVer('1.1.0', '1.2.0'), isNegative);
    });

    test('patch differences', () {
      expect(compareSemVer('1.1.2', '1.1.1'), isPositive);
      expect(compareSemVer('1.1.1', '1.1.2'), isNegative);
    });

    test('numeric ordering exceeds lexicographic', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('short-form padding defaults missing components to zero', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1.2.0', '1.2'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
    });

    test('extra-component truncation ignores after patch', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3', '1.2.3.4'), equals(0));
    });

    test('throws FormatException on malformed input (type assertion)', () {
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('   ', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('FormatException message contains offending input', () {
      const offendingInput = '1.2.a';
      expect(
        () => compareSemVer(offendingInput, '1.2.3'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(offendingInput),
        )),
      );

      const emptyInput = '  ';
      expect(
        () => compareSemVer(emptyInput, '1.2.3'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(emptyInput),
        )),
      );
    });
  });
}
