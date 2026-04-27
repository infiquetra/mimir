import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns unchanged input when length is within maxLength', () {
      expect(truncateMiddle('hello', 10), equals('hello'));
      expect(truncateMiddle('hello', 5), equals('hello'));
    });

    test('replaces the middle while preserving start and end', () {
      expect(truncateMiddle('abcdefghijklmn', 8), equals('abcd…lmn'));
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), equals(''));
    });

    test('returns a truncated ellipsis when maxLength is too small', () {
      expect(truncateMiddle('abcdef', 0), equals(''));
      expect(truncateMiddle('abcdef', 1), equals('…'));
    });

    test('accounts for custom ellipsis length', () {
      expect(
        truncateMiddle('abcdefghijklmn', 8, ellipsis: '...'),
        equals('abc...mn'),
      );
    });
  });
}
