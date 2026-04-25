import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/semver.dart';

void main() {
  group('compareSemVer', () {
    test('equal versions returns zero', () {
      expect(compareSemVer('1.2.3', '1.2.3'), equals(0));
    });

    test('major difference returns correct sign', () {
      expect(compareSemVer('2.0.0', '1.0.0'), isPositive);
      expect(compareSemVer('1.0.0', '2.0.0'), isNegative);
    });

    test('minor difference returns correct sign', () {
      expect(compareSemVer('1.3.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.3.0'), isNegative);
    });

    test('patch difference returns correct sign', () {
      expect(compareSemVer('1.2.4', '1.2.3'), isPositive);
      expect(compareSemVer('1.2.3', '1.2.4'), isNegative);
    });

    test('numeric ordering works correctly', () {
      // 1.10.0 > 1.2.0 (numeric, not lexicographic)
      expect(compareSemVer('1.10.0', '1.2.0'), isPositive);
      expect(compareSemVer('1.2.0', '1.10.0'), isNegative);
    });

    test('short form pads missing components with zero', () {
      expect(compareSemVer('1.2', '1.2.0'), equals(0));
      expect(compareSemVer('1', '1.0.0'), equals(0));
      expect(compareSemVer('1.2', '1.2.3'), isNegative);
    });

    test('extra trailing components are ignored', () {
      expect(compareSemVer('1.2.3.4', '1.2.3'), equals(0));
      expect(compareSemVer('1.2.3.4.5', '1.2.3'), equals(0));
    });

    test('malformed input throws FormatException', () {
      expect(
        () => compareSemVer('1.2.a', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
    });

    test('FormatException message contains the offending input', () {
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

    test('empty or whitespace-only input throws FormatException', () {
      expect(
        () => compareSemVer('', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => compareSemVer('   ', '1.2.3'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
