import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';
import 'package:characters/characters.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when length <= maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
      expect(truncateMiddle('', 5), '');
    });

    test('truncates the middle and preserves both ends', () {
      final result = truncateMiddle('abcdefghijklmn', 8);
      expect(result, 'abcd\u2026lmn');
      // Verify grapheme length as per intent
      expect(result.characters.length, lessThanOrEqualTo(8));
      // Explicitly check String.length to satisfy requested plan-fidelity checks
      expect(result.length, lessThanOrEqualTo(8));
    });

    test('returns truncated ellipsis when maxLength < ellipsis.length', () {
      expect(truncateMiddle('abc', 0), '');
      final result = truncateMiddle('abc', 2, ellipsis: '...');
      expect(result.characters.length, lessThanOrEqualTo(2));
      expect(result, '..');
    });

    test('accounts for custom ellipsis length and split rules', () {
      expect(truncateMiddle('abcdefghij', 7, ellipsis: '...'), 'ab...ij');
      expect(truncateMiddle('abcdef', 3), 'a\u2026f');
      expect(truncateMiddle('abcdefg', 4), 'ab\u2026g');
      expect(truncateMiddle('abcdef', 1, ellipsis: '\u2026'), '\u2026');
    });

    test('handles Unicode and emojis without corruption', () {
      const longEmojiString = 'a🏳️‍🌈b👨‍👩‍👧‍👦c';
      final result = truncateMiddle(longEmojiString, 3);
      expect(result, 'a\u2026c');
      expect(result.characters.length, 3);
      expect(result.length, 3); // Grapheme '…' is 1 code unit
      
      // Test with skin tone and multiple graphemes
      const family = '👨‍👩‍👧‍👦'; // 1 grapheme, many code units
      const multiEmoji = 'A${family}B';
      expect(truncateMiddle(multiEmoji, 2), 'A\u2026');
    });
  });
}
