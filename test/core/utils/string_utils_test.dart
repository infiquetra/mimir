import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when shorter than maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
    });

    test('returns input unchanged when length equals maxLength', () {
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('returns single-character input unchanged when within maxLength', () {
      expect(truncateMiddle('x', 1), 'x');
      expect(truncateMiddle('x', 5), 'x');
    });

    test('replaces the middle while keeping start and end visible', () {
      // maxLength=8, ellipsis=1 → visible=7 → start=4, end=3 (odd to start)
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('returns truncated ellipsis when maxLength is shorter than ellipsis',
        () {
      expect(truncateMiddle('hello', 1, ellipsis: '……'), '…');
      expect(truncateMiddle('hello', 2, ellipsis: '……'), '……'.substring(0, 2));
    });

    test('counts custom ellipsis length toward maxLength', () {
      // 3-char ellipsis + 1 start + 1 end = 5 total ≤ maxLength=5
      expect(truncateMiddle('abcdefgh', 5, ellipsis: '...'), 'a...h');
      // maxLength=6: visible=6-3=3 → start=2, end=1 → 'ab...i' (6 chars)
      expect(truncateMiddle('abcdefghij', 6, ellipsis: '...'), 'ab...j');
    });

    test('gives the odd extra visible character to the start consistently', () {
      // maxLength=7, ellipsis=1 → visible=6 → start=3, end=3 → 'abc…hij' (7)
      expect(truncateMiddle('abcdefghij', 7), 'abc…hij');
      // maxLength=8, ellipsis=1 → visible=7 → start=4, end=3 → 'abcd…hij' (8)
      expect(truncateMiddle('abcdefghij', 8), 'abcd…hij');
    });

    test('throws ArgumentError when maxLength is negative', () {
      expect(() => truncateMiddle('hello', -1), throwsArgumentError);
    });
  });
}
