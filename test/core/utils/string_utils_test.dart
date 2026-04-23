import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns unchanged string when within maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hi', 5), 'hi');
    });

    test('truncates middle and keeps start and end visible', () {
      // 'abcdefghijklmn' has 14 chars, maxLength=8
      // ellipsis='…' length=1, visibleBudget = 8-1 = 7
      // startLength = (7+1)/2 = 4, endLength = 7/2 = 3
      // Result: 'abcd' + '…' + 'lmn' = 'abcd…lmn' (7 chars total, ≤8)
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
    });

    test('handles empty input', () {
      expect(truncateMiddle('', 5), '');
      expect(truncateMiddle('', 0), '');
      expect(truncateMiddle('', 1), '');
    });

    test('returns truncated ellipsis when maxLength is smaller than ellipsis length', () {
      // ellipsis '…' has length 1, but if we had a multi-character ellipsis
      // and maxLength was smaller, we'd truncate it
      // For '…' (length 1) with maxLength=0, no room for content or ellipsis
      expect(truncateMiddle('abcdef', 0), '');
    });

    test('custom multi-character ellipsis with sufficient maxLength', () {
      // maxLength=6, ellipsis='***' (length 3), visibleBudget=3
      // 'abcdefg' (7 chars) needs truncation
      // startLength = (3+1)/2 = 2, endLength = 3/2 = 1
      // Result: 'ab' + '***' + 'g' = 'ab***g' (6 chars)
      expect(truncateMiddle('abcdefg', 6, ellipsis: '***'), 'ab***g');
    });

    test('truncated ellipsis when maxLength < ellipsis.length', () {
      // maxLength=2, ellipsis='…' (length 1), visibleBudget=1
      // visibleBudget < 2, so return truncated ellipsis
      // '…' substring(0, 2) = '…' (already length 1, fits)
      expect(truncateMiddle('abcdef', 2), '…');
    });

    test('design choice: maxLength=3 returns a…f', () {
      // input='abcdef' (6 chars), maxLength=3
      // ellipsis='…' (length 1), visibleBudget=2
      // startLength = (2+1)/2 = 1, endLength = 2/2 = 1
      // Result: 'a' + '…' + 'f' = 'a…f' (3 chars total)
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('result length is always <= maxLength', () {
      // For various inputs, verify length constraint
      expect(truncateMiddle('hello world', 8).length <= 8, true);
      expect(truncateMiddle('testing', 5).length <= 5, true);
      expect(truncateMiddle('exactly', 7).length <= 7, true);
      expect(truncateMiddle('short', 10).length <= 10, true);
    });
  });
}
