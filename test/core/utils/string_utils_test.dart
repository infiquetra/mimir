import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when length is within maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello'); // equality boundary
    });

    test('replaces the middle with ellipsis while keeping both ends visible', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abc…lmn');
      expect(truncateMiddle('abcdefghijklmn', 8).length, lessThanOrEqualTo(8));
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('returns truncated ellipsis when maxLength is too small', () {
      expect(truncateMiddle('abcdef', 0), '');
      expect(truncateMiddle('abcdef', 1), '…');
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
    });

    test('accounts for custom ellipsis length in the maximum length', () {
      expect(truncateMiddle('abcdefghijklmn', 8, ellipsis: '...'), 'ab...mn');
      expect(truncateMiddle('abcdefghijklmn', 8, ellipsis: '...').length, lessThanOrEqualTo(8));
    });

    test('keeps one character on each side when maxLength permits', () {
      // With default ellipsis (single char) and maxLength = 3,
      // we have 2 visible chars split evenly: 1 char each side
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('throws ArgumentError when maxLength is negative', () {
      expect(() => truncateMiddle('abc', -1), throwsArgumentError);
      expect(() => truncateMiddle('abc', -100), throwsArgumentError);
    });

    test('handles short strings and single character strings', () {
      expect(truncateMiddle('a', 1), 'a');
      expect(truncateMiddle('ab', 2), 'ab');
      expect(truncateMiddle('abc', 3), 'abc');
    });
  });
}
