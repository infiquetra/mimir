import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns unchanged input when length is less than maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('a', 5), 'a');
      expect(truncateMiddle('', 5), '');
    });

    test('returns unchanged input when length equals maxLength', () {
      expect(truncateMiddle('hello', 5), 'hello');
      expect(truncateMiddle('', 0), '');
    });

    test('replaces the middle with the default ellipsis', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abc…lmn');
      // length check: 3 + 1 + 3 = 7 ≤ 8
      expect(truncateMiddle('abcdefghijklmn', 8).length, 7);
    });

    test('returns empty string when maxLength <= 0', () {
      expect(truncateMiddle('hello', 0), '');
      expect(truncateMiddle('hello', -5), '');
      expect(truncateMiddle('', 0), '');
      expect(truncateMiddle('', -1), '');
    });

    test('returns truncated ellipsis when maxLength is shorter than ellipsis',
        () {
      expect(truncateMiddle('abcdef', 2, ellipsis: '---'), '--');
      expect(truncateMiddle('abcdef', 2, ellipsis: '---').length, 2);
      expect(truncateMiddle('abcdef', 0, ellipsis: 'xyz'), '');
      expect(truncateMiddle('abcdef', 1, ellipsis: 'xyz'), 'x');
    });

    test('uses ellipsis length when calculating the result length', () {
      expect(truncateMiddle('abcdefghijklmn', 9, ellipsis: '...'), 'abc...lmn');
      expect(truncateMiddle('abcdefghijklmn', 9, ellipsis: '...').length, 9);
      // ellipsis length = 3, available = 6, sideLength = 3 each
      expect(truncateMiddle('abcdefghijklmn', 9, ellipsis: '...').length, 9);
    });

    test('documents the small maxLength design choice', () {
      // maxLength = 3, ellipsis length = 1 (default), available = 2, sideLength = 1
      expect(truncateMiddle('abcdef', 3), 'a…f');
      expect(truncateMiddle('abcdef', 3).length, 3);
    });

    test('handles odd available length leaving leftover unused', () {
      // maxLength = 9, ellipsis length = 1, available = 8, sideLength = 4 each
      expect(truncateMiddle('abcdefghijklmnop', 9), 'abcd…mnop');
      expect(truncateMiddle('abcdefghijklmnop', 9).length, 9);
    });

    test('works with multi-character ellipsis', () {
      expect(truncateMiddle('abcdefghijklmnop', 12, ellipsis: '<...>'),
          'abc<...>nop');
      // length check: 3 + 5 + 3 = 11 ≤ 12
      expect(
          truncateMiddle('abcdefghijklmnop', 12, ellipsis: '<...>').length, 11);
    });
  });
}
