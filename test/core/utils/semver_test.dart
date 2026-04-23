import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions return zero', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
      expect(compareSemVer('0.0.0', '0.0.0'), equals(0));
    });

    test('major difference determines sign', () {
      expect(compareSemVer('1.2.3', '2.0.0'), isNegative);
      expect(compareSemVer('2.0.0', '1.2.3'), isPositive);
    });

    test('minor difference determines sign', () {
      expect(compareSemVer('1.2.3', '1.3.0'), isNegative);
      expect(compareSemVer('1.3.0', '1.2.3'), isPositive);
    });

    test('patch difference determines sign', () {
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
    });

    test('numeric ordering works (not lexicographic)', () {
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('short-form padding (missing components default to zero)', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1.2', '1.2.1'), isNegative);
      expect(compareSemVer('1.2.1', '1.2'), isPositive);
    });

    test('extra trailing components are ignored', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3.4.5', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3', '1.2.3.4'), equals(0));
      expect(compareSemVer('1.2.3.9', '1.2.4'), isNegative);
      expect(compareSemVer('1.2.4', '1.2.3.9'), isPositive);
    });

    group('malformed input throws FormatException', () {
      test('empty string', () {
        expect(() => compareSemVer('', '1.2.3'),
            throwsA(isA<FormatException>()));
        expect(() => compareSemVer('1.2.3', ''),
            throwsA(isA<FormatException>()));
      });

      test('purely whitespace string', () {
        expect(() => compareSemVer('   ', '1.2.3'),
            throwsA(isA<FormatException>()));
        expect(() => compareSemVer('1.2.3', '\t\n'),
            throwsA(isA<FormatException>()));
      });

      test('non-numeric component', () {
        expect(() => compareSemVer('1.2.a', '1.2.3'),
            throwsA(isA<FormatException>()));
        expect(() => compareSemVer('1.2.3', 'a.b.c'),
            throwsA(isA<FormatException>()));
        expect(() => compareSemVer('1.2.-3', '1.2.3'),
            throwsA(isA<FormatException>()));
        expect(() => compareSemVer('1.2.3', '1.2.3.alpha'),
            throwsA(isA<FormatException>()));
      });

      test('FormatException message contains the offending input substring',
          () {
        expect(
            () => compareSemVer('1.2.a', '1.2.3'),
            throwsA(isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('1.2.a'),
            )));
        expect(
            () => compareSemVer('', '1.2.3'),
            throwsA(isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(''),
            )));
        expect(
            () => compareSemVer('   ', '1.2.3'),
            throwsA(isA<FormatException>().having(
              (e) => e.message,
              'message',
              anyOf(contains('   '), contains('empty or whitespace')),
            )));
        expect(
            () => compareSemVer('1.2.3', 'a.b.c'),
            throwsA(isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('a.b.c'),
            )));
      });
    });
  });
}