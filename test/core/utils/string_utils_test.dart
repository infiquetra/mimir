import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when length <= maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('truncates the middle and preserves both ends', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
    });

    test('returns empty string for empty input', () {
      expect(truncateMiddle('', 5), '');
    });

    test('returns truncated ellipsis when maxLength < ellipsis.length', () {
      expect(truncateMiddle('abc', 0), '');
      expect(truncateMiddle('abc', 2, ellipsis: '...'), '..');
    });

    test('accounts for custom ellipsis length', () {
      expect(truncateMiddle('abcdefghij', 7, ellipsis: '...'), 'ab...ij');
    });

    test('uses documented odd-budget split rule consistently', () {
      expect(truncateMiddle('abcdef', 3), 'a…f');
      expect(truncateMiddle('abcdefg', 4), 'ab…g');
    });
    
    test('handles maxLength exactly equal to ellipsis length', () {
       expect(truncateMiddle('abcdef', 1, ellipsis: '…'), '…');
    });
  });
}
