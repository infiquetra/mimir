import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    group('equal versions', () {
      test('returns zero for identical versions', () {
        expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
      });

      test('returns zero for short form padded version', () {
        expect(compareSemVer('1.2', '1.2.0'), equals(0));
      });

      test('returns zero when extra components are ignored', () {
        expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      });
    });

    group('major difference', () {
      test('returns negative when a has smaller major', () {
        expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
      });

      test('returns positive when a has larger major', () {
        expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
      });
    });

    group('minor difference', () {
      test('returns negative when a has smaller minor', () {
        expect(compareSemVer('1.2.0', '1.3.0'), isNegative);
      });

      test('returns positive when a has larger minor', () {
        expect(compareSemVer('1.3.0', '1.2.0'), isPositive);
      });
    });

    group('patch difference', () {
      test('returns negative when a has smaller patch', () {
        expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
      });

      test('returns positive when a has larger patch', () {
        expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
      });
    });

    group('numeric ordering', () {
      test('compares numerically not lexicographically', () {
        expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      });

      test('handles large version numbers correctly', () {
        expect(compareSemVer('2.0.0', '1.99.99'), isPositive);
      });
    });

    group('malformed input', () {
      test('throws FormatException for non-numeric component', () {
        expect(
          () => compareSemVer('1.2.a', '1.2.3'),
          throwsA(isA<FormatException>()),
        );
      });

      test('FormatException message contains offending input for non-numeric component', () {
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

      test('throws FormatException for empty string', () {
        expect(
          () => compareSemVer('', '1.2.3'),
          throwsA(isA<FormatException>()),
        );
      });

      test('FormatException message contains offending input for empty string', () {
        expect(
          () => compareSemVer('', '1.2.3'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(''),
            ),
          ),
        );
      });

      test('throws FormatException for whitespace-only string', () {
        expect(
          () => compareSemVer('   ', '1.2.3'),
          throwsA(isA<FormatException>()),
        );
      });

      test('FormatException message contains offending input for whitespace-only string', () {
        expect(
          () => compareSemVer('   ', '1.2.3'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('   '),
            ),
          ),
        );
      });

      test('throws FormatException for empty component', () {
        expect(
          () => compareSemVer('1..2', '1.2.3'),
          throwsA(isA<FormatException>()),
        );
      });

      test('FormatException message contains offending input for empty component', () {
        expect(
          () => compareSemVer('1..2', '1.2.3'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('1..2'),
            ),
          ),
        );
      });

      test('throws FormatException for leading dot (empty first component)', () {
        expect(
          () => compareSemVer('.1.2', '1.2.3'),
          throwsA(isA<FormatException>()),
        );
      });

      test('FormatException message contains offending input for leading dot', () {
        expect(
          () => compareSemVer('.1.2', '1.2.3'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('.1.2'),
            ),
          ),
        );
      });
    });
  });
}
