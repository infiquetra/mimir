import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when already within max length', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('abc', 5), 'abc');
      expect(truncateMiddle('', 5), '');
    });

    test('truncates the middle and keeps both ends visible', () {
      // maxLength=7: visibleCount=6, prefix=3, suffix=3 → 'abc…hij' (7 chars)
      expect(truncateMiddle('abcdefghij', 7), 'abc…hij');
      // maxLength=8: visibleCount=7, prefix=4, suffix=3 → 'abcd…lmn' (8 chars)
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
      expect(truncateMiddle('', 0), '');
    });

    test('returns truncated ellipsis when max length is shorter than ellipsis', () {
      expect(truncateMiddle('abcdef', 2), '…');
      expect(truncateMiddle('abcdef', 1), '…');
      expect(truncateMiddle('abcdef', 0), '');
      // maxLength < ellipsis.length → truncate ellipsis to fit
      expect(truncateMiddle('abcdef', 2, ellipsis: '....'), '..');
    });

    test('counts custom ellipsis length in the max length budget', () {
      // '..' is 2 chars, input 8 chars, budget=6, visible=4, prefix=2, suffix=2
      expect(truncateMiddle('abcdefgh', 6, ellipsis: '..'), 'ab..gh');
      // maxLength=3, ellipsis='...' (3 chars), budget exhausted, returns '...'
      expect(truncateMiddle('abcdef', 3, ellipsis: '...'), '...');
    });

    test('distributes odd visible budget to prefix consistently', () {
      // maxLength=5, ellipsis=1, visible=4, prefix=2, suffix=2
      expect(truncateMiddle('abcdefgh', 5), 'ab…gh');
      // maxLength=6, ellipsis=1, visible=5, prefix=3, suffix=2
      expect(truncateMiddle('abcdefgh', 6), 'abc…gh');
      // maxLength=3, ellipsis=1, visible=2, prefix=1, suffix=1 → 'a…f'
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });
  });
}
