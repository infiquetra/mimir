import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns unchanged short string when input length is less than maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
    });

    test('returns empty string when input is empty', () {
      expect(truncateMiddle('', 5), '');
    });

    test('truncates middle with odd visible budget favoring the start', () {
      // 14 chars input, maxLength=8, ellipsis='…' (1 char)
      // Visible budget = 8 - 1 = 7 chars
      // leadingCount = (7 + 1) ~/ 2 = 4, trailingCount = 7 ~/ 2 = 3
      // Result: 'abcd' + '…' + 'lmn' = 'abcd…lmn'
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
    });

    test('handles short max length that still leaves room for one leading and one trailing character', () {
      // 6 chars input, maxLength=3, ellipsis='…' (1 char)
      // Visible budget = 3 - 1 = 2 chars
      // leadingCount = (2 + 1) ~/ 2 = 1, trailingCount = 2 ~/ 2 = 1
      // Result: 'a' + '…' + 'f' = 'a…f'
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('returns empty string when maxLength is zero or negative', () {
      expect(truncateMiddle('abcdef', 0), '');
      expect(truncateMiddle('abcdef', -1), '');
    });

    test('handles custom ellipsis length consideration', () {
      // 10 chars input, maxLength=7, ellipsis='...' (3 chars)
      // Visible budget = 7 - 3 = 4 chars
      // leadingCount = (4 + 1) ~/ 2 = 2, trailingCount = 4 ~/ 2 = 2
      // Result: 'ab' + '...' + 'ij' = 'ab...ij'
      expect(truncateMiddle('abcdefghij', 7, ellipsis: '...'), 'ab...ij');
    });

    test('truncates ellipsis when custom ellipsis itself is too long', () {
      // 6 chars input, maxLength=2, ellipsis='...' (3 chars)
      // Since maxLength < ellipsis.length, return ellipsis.substring(0, maxLength)
      // Result: '..' (first 2 chars of '...')
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
    });

    test('handles single character input with sufficient maxLength', () {
      expect(truncateMiddle('a', 5), 'a');
    });

    test('handles single character input with insufficient maxLength', () {
      expect(truncateMiddle('a', 0), '');
    });
  });
}