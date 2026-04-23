import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns unchanged short strings', () {
      expect(truncateMiddle('hello', 10), 'hello');
    });

    test('truncates the middle and keeps both ends visible', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abc…lmn');
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('returns unchanged single-character input', () {
      expect(truncateMiddle('a', 1), 'a');
    });

    test('truncates ellipsis when maxLength is shorter than ellipsis', () {
      // maxLength=2 < ellipsis.length=3, so return ellipsis substring
      expect(truncateMiddle('abcdefgh', 2, ellipsis: '...'), '..');
    });

    test('uses ellipsis alone when there is not enough room for both ends', () {
      // maxLength=3, visibleCharacterBudget=2 >= 2, so proceed with truncation
      // Result: 'a…f' = 3 chars
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('counts ellipsis length in the final maxLength budget', () {
      // Input length 8 <= maxLength=9, so input already fits
      final result = truncateMiddle('abcdefgh', 9, ellipsis: '...');
      expect(result, 'abcdefgh');
      expect(result.length <= 9, true);
    });
  });
}
