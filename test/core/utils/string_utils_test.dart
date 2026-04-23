import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns unchanged string when input length is <= maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hi', 2), 'hi');
      expect(truncateMiddle('', 5), '');
    });

    test('truncates middle of long strings correctly', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
      expect(truncateMiddle('abcdefghijklmnop', 10), 'abcde…mnop');
    });

    test('handles empty input string', () {
      expect(truncateMiddle('', 5), '');
    });

    test('handles maxLength too small edge cases', () {
      expect(truncateMiddle('abcdef', 1), '…');
      expect(truncateMiddle('abcdef', 0), '');
      expect(truncateMiddle('abcdef', -1), '');
    });

    test('handles ellipsis length considerations', () {
      expect(truncateMiddle('abcdef', 4, ellipsis: '...'), 'a...');
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
      expect(truncateMiddle('abcdef', 5, ellipsis: '**'), 'ab**f');
    });

    test('documents the ambiguous case design choice', () {
      // When maxLength equals ellipsis.length + 2, we get 1 visible char on each side
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('handles single character strings', () {
      expect(truncateMiddle('a', 1), 'a');
      expect(truncateMiddle('a', 0), '');
    });
  });
}