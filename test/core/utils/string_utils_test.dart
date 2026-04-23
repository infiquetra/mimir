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
      // Default ellipsis is '…' (length 1). If maxLength is 0, returns ''.
      expect(truncateMiddle('abcdef', 0), '');

      // Custom ellipsis '---' (length 3), maxLength 2 -> returns '--'
      expect(truncateMiddle('abcdef', 2, ellipsis: '---'), '--');
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
      expect(truncateMiddle('a', 0), '');
    });
  });
}
