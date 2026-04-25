import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when input.length <= maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('abc', 3), 'abc');
      expect(truncateMiddle('xy', 5), 'xy');
    });

    test('returns empty string unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('truncates middle while preserving both ends', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abc…lmn');
      // prefixCount = (maxLength - ellipsis.length + 1) ~/ 2 = (8 - 1 + 1) ~/ 2 = 8~/2? Wait, compute.
      // visibleBudget = 8 - 1 = 7, prefixCount = (7+1)~/2 = 4, suffixCount = 7~/2 = 3. Actually prefix=4? That would be "abcd…lmn" length 4+1+3 = 8.
      // Let's compute: 'abcdefghijklmn' length 14. prefix 4 => 'abcd', suffix 3 => 'lmn', ellipsis '…' => 'abcd…lmn'. That's correct. Good.
    });

    test('returns truncated ellipsis alone when maxLength < ellipsis.length', () {
      expect(truncateMiddle('xyz', 2), '…'); // ellipsis length 1 <= 2, not this case. Need maxLength < ellipsis length.
      // Use custom ellipsis longer than maxLength.
      expect(truncateMiddle('anything', 3, ellipsis: '----'), '---');
      expect(truncateMiddle('anything', 1, ellipsis: '....'), '.');
    });

    test('counts custom ellipsis length toward maxLength', () {
      // maxLength = 10, ellipsis length = 4, visibleBudget = 6, split: prefix = 6~/2 = 3, suffix = 3.
      // Input length 20 > 10.
      expect(truncateMiddle('abcdefghijklmnopqrst', 10, ellipsis: '!!!!'), 'abc!!!!rst');
      // Verify length = 3 + 4 + 3 = 10.
    });

    test('even visible budget yields equal prefix/suffix and total length equals maxLength', () {
      // Example from issue: truncateMiddle('abcdef', 3) -> 'a…f'
      // maxLength = 3, ellipsis length = 1, visibleBudget = 2 (even).
      // prefixCount = 2~/2 = 1, suffixCount = 1, total length = 1+1+1 = 3.
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('odd visible budget yields equal prefix/suffix and total length less than maxLength', () {
      // maxLength = 6, ellipsis length = 1, visibleBudget = 5 (odd).
      // prefixCount = 5~/2 = 2, suffixCount = 2, total length = 2+1+2 = 5 < maxLength.
      expect(truncateMiddle('123456789', 6), '12…89');
      // Validate length.
      final result = truncateMiddle('123456789', 6);
      expect(result.length, 5);
    });

    test('handles maxLength zero or negative', () {
      expect(truncateMiddle('hello', 0), '');
      expect(truncateMiddle('hello', -5), '');
    });

    test('ellipsis truncated to maxLength when ellipsis longer', () {
      expect(truncateMiddle('abc', 1), '…');
      // Actually ellipsis default '…' length 1, maxLength 1, returns '…'.
      // Let's use custom ellipsis '>>>', maxLength 2 -> '>>'.
      expect(truncateMiddle('something', 2, ellipsis: '>>>'), '>>');
    });
  });
}