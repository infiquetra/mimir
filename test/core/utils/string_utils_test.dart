

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when length is within maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('abc', 3), 'abc');
      expect(truncateMiddle('', 5), '');
    });

    test('returns empty when maxLength <= 0', () {
      expect(truncateMiddle('hello', 0), '');
      expect(truncateMiddle('world', -1), '');
      expect(truncateMiddle('', 0), '');
    });

    test('truncates the middle and preserves both ends', () {
      // Example from spec – allocate‑odd‑to‑start yields 'abcd…lmn' (not 'abc…lmn')
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
      // Additional cases
      expect(truncateMiddle('1234567890', 6), '123…90');
      expect(truncateMiddle('abcdefgh', 5), 'ab…gh');
    });

    test('counts multi‑character ellipsis against maxLength', () {
      // When input fits within maxLength, it's returned unchanged per spec
      expect(truncateMiddle('abcdefgh', 8, ellipsis: '...'), 'abcdefgh');
      // Truncation cases where input exceeds maxLength
      expect(truncateMiddle('1234567890', 7, ellipsis: '...'), '12...90');
      expect(truncateMiddle('abcdefghijklmnop', 10, ellipsis: '...'), 'abcd...nop');
    });

    test('returns truncated ellipsis when maxLength is shorter than ellipsis', () {
      expect(truncateMiddle('hello', 2, ellipsis: '...'), '..');
      expect(truncateMiddle('world', 1, ellipsis: '…'), '…');
      // Empty input with maxLength=1 returns '' per spec (input.length <= maxLength)
      expect(truncateMiddle('', 1, ellipsis: '...'), '');
    });

    test('distributes odd visible‑budget extra character to the start', () {
      // maxLength=3, ellipsis='…'(length=1), visibleBudget=2 → 2 visible chars
      // leadingLength=(2+1)~/2=1, trailingLength=2~/2=1 → "a" + "…" + "f"
      expect(truncateMiddle('abcdef', 3), 'a…f');
      // Additional odd‑budget example
      expect(truncateMiddle('1234567', 5), '12…67'); // maxLength=5, ellipsis length=1, visibleBudget=4 → leadingLength=2, trailingLength=2
    });

    test('result length never exceeds maxLength', () {
      final cases = [
        ['hello', 10],
        ['abcdefghijklmn', 8],
        ['', 5],
        ['abcdef', 3],
        ['1234567890', 6],
        ['abcdefgh', 5],
        ['abcdefgh', 8, '...'],
        ['hello', 2, '...'],
        ['world', 1, '…'],
        ['', 1, '...'],
      ];
      for (final c in cases) {
        final input = c[0] as String;
        final maxLength = c[1] as int;
        final ellipsis = c.length > 2 ? c[2] as String : '…';
        final result = truncateMiddle(input, maxLength, ellipsis: ellipsis);
        expect(result.length <= maxLength, isTrue,
            reason: 'Input "$input", maxLength $maxLength, result "$result" length ${result.length}');
      }
    });
  });
}
