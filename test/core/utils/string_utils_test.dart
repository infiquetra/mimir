

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when it fits within maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('truncates the middle while preserving start and end', () {
      // maxLength = 8, ellipsis.length = 1 ('…'), visible characters = 7
      // expected: startLength = (7+1)~/2 = 4, endLength = 7~/2 = 3
      // 'abcd' + '…' + 'lmn' → 'abcd…lmn'
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
      expect(truncateMiddle('abcdefghijklmn', 8).length <= 8, isTrue);
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('returns truncated ellipsis when maxLength is shorter than ellipsis',
        () {
      // ellipsis '...' length = 3, maxLength = 2 → ellipsis.substring(0, 2) = '..'
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
      expect(truncateMiddle('abcdef', 2, ellipsis: '...').length, 2);
    });

    test('accounts for ellipsis length when truncating', () {
      // ellipsis '...' length = 3, maxLength = 10 → visible characters = 7
      // startLength = (7+1)~/2 = 4, endLength = 7~/2 = 3
      // 'abcd' + '...' + 'lmn' → 'abcd...lmn'
      expect(
          truncateMiddle('abcdefghijklmn', 10, ellipsis: '...'), 'abcd...lmn');
      expect(truncateMiddle('abcdefghijklmn', 10, ellipsis: '...').length, 10);
    });

    test(
        'documents maxLength three behavior as keeping one character on each side',
        () {
      // design choice: when maxLength = 3 and ellipsis = '…' (length 1),
      // visibleCharacters = 2, startLength = (2+1)~/2 = 1, endLength = 2~/2 = 1
      // 'a' + '…' + 'f' → 'a…f'
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('handles single character strings', () {
      expect(truncateMiddle('x', 5), 'x');
      expect(truncateMiddle('x', 1), 'x');
      expect(truncateMiddle('x', 0), '');
    });

    test('handles non‑positive maxLength', () {
      expect(truncateMiddle('hello', 0), '');
      expect(truncateMiddle('hello', -1), '');
    });

    test('works with custom long ellipsis', () {
      // ellipsis '~~~' length = 3, maxLength = 5
      // input 'abcde' length = 5 ≤ maxLength, so returns unchanged
      expect(truncateMiddle('abcde', 5, ellipsis: '~~~'), 'abcde');
      // When input doesn't fit, applies truncation correctly
      expect(truncateMiddle('abcdef', 5, ellipsis: '~~~'), 'a~~~f');
      expect(truncateMiddle('abcdef', 5, ellipsis: '~~~').length, 5);
    });
  });
}
