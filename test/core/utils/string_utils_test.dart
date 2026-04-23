import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when shorter than maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('mimir', 5), 'mimir');
    });

    test('truncates the middle while keeping both ends visible', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('returns truncated ellipsis when maxLength is shorter than ellipsis', () {
      // maxLength=0 is now invalid (throws)
      expect(() => truncateMiddle('abcdef', 0), throwsA(isA<ArgumentError>()));

      // Custom ellipsis '---' (length 3), maxLength 2 -> returns '--'
      expect(truncateMiddle('abcdef', 2, ellipsis: '---'), '--');
    });

    test('throws ArgumentError for non-positive maxLength', () {
      expect(() => truncateMiddle('abcdef', -1), throwsA(isA<ArgumentError>()));
      expect(() => truncateMiddle('abcdef', 0), throwsA(isA<ArgumentError>()));
    });

    test('returns truncated ellipsis when maxLength is smaller than ellipsis (multi-char ellipsis)', () {
      // maxLength=2, ellipsis='---' (length 3). Since ellipsis > maxLength, returns first 2 chars.
      expect(truncateMiddle('some long text', 2, ellipsis: '---'), '--');

      // maxLength=3, ellipsis='>>>' (length 3). Since ellipsis == maxLength, returns all 3.
      expect(truncateMiddle('some long text', 3, ellipsis: '>>>'), '>>>');

      // maxLength=4, ellipsis='>>>' (length 3). visibleBudget=1, start=1, end=0.
      // 's' + '>>>' = 's>>>' (length 4)
      expect(truncateMiddle('some long text', 4, ellipsis: '>>>'), 's>>>');
    });

    test('counts custom ellipsis length against maxLength', () {
      // 'abcdefghi', maxLength 8, ellipsis '---' (3)
      // Budget = 8 - 3 = 5
      // start = 3, end = 2
      // 'abc' + '---' + 'hi' = 'abc---hi' (length 7, <= 8)
      expect(truncateMiddle('abcdefghi', 8, ellipsis: '---'), 'abc---hi');
    });

    test('documents the chosen 3-character behavior as a…f', () {
      // 'abcdef', maxLength 3, ellipsis '…' (1)
      // Budget = 3 - 1 = 2
      // start = 1, end = 1
      // 'a' + '…' + 'f' = 'a…f'
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('handles single character strings', () {
      expect(truncateMiddle('a', 1), 'a');
      // maxLength=0 is now invalid (throws)
      expect(() => truncateMiddle('a', 0), throwsA(isA<ArgumentError>()));
    });
  });
}
