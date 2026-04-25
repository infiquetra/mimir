import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('major difference', () {
      expect(compareSemVer('2.0.0', '1.9.9'), isPositive);
      expect(compareSemVer('1.9.9', '2.0.0'), isNegative);
    });

    test('minor difference', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('patch difference', () {
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
    });

    test('numeric ordering', () {
      // Proves it's not lexicographical
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
    });

    test('short-form padding', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
      expect(compareSemVer('1.2.1', '1.2'), isPositive);
    });

    test('extra-component truncation', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3', '1.2.3.4'), equals(0));
    });

    test('FormatException type assertion', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('   ', '1.2.3'), throwsA(isA<FormatException>()));
    });

    test('FormatException message-content assertion', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('1.2.a'))),
      );
      expect(
        () => compareSemVer('1.2.3', ''),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(''))),
      );
      expect(
        () => compareSemVer('1.2.3', '   '),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('   '))),
      );
    });
  });
}
