import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('returns zero for equal versions', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
      expect(compareSemVer('1.0.0', '1.0.0'), equals(0));
    });

    test('returns positive when major version is greater', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
      expect(compareSemVer('10.0.0', '2.0.0'), isPositive);
    });

    test('returns negative when major version is lesser', () {
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
      expect(compareSemVer('2.0.0', '10.0.0'), isNegative);
    });

    test('returns positive when minor version is greater', () {
      expect(compareSemVer('1.3.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
    });

    test('returns negative when minor version is lesser', () {
      expect(compareSemVer('1.2.0', '1.3.0'), isNegative);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('returns positive when patch version is greater', () {
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
      expect(compareSemVer('1.2.10', '1.2.2'), isPositive);
    });

    test('returns negative when patch version is lesser', () {
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
      expect(compareSemVer('1.2.2', '1.2.10'), isNegative);
    });

    test('compares numeric components numerically rather than lexicographically', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
      expect(compareSemVer('2.0.0', '1.99.99'), isPositive);
    });

    test('treats missing patch as zero', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1.2.0', '1.2'), equals(0));
    });

    test('ignores components beyond patch', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3', '1.2.3.4'), equals(0));
      expect(compareSemVer('1.2.3.4', '1.2.3.5'), equals(0));
    });

    test('throws FormatException for malformed versions', () {
      expect(() => compareSemVer('1.2.a', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', '1.2.a'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('a.b.c', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', ''), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('  ', '1.2.3'), throwsA(isA<FormatException>()));
      expect(() => compareSemVer('1.2.3', '  '), throwsA(isA<FormatException>()));
    });

    test('includes the offending input in the FormatException message', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('1.2.a'))),
      );
      
      expect(
        () => compareSemVer('1.2.3', 'x.y.z'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('x.y.z'))),
      );
      
      expect(
        () => compareSemVer('', '1.2.3'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(''))),
      );
    });
  });
}