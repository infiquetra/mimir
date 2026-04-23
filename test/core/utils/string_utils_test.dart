import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when length <= maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
      expect(truncateMiddle('', 5), '');
    });

    test('handles single-character input', () {
      expect(truncateMiddle('a', 1), 'a');
      expect(truncateMiddle('a', 5), 'a');
    });

    test('truncates the middle and preserves both ends', () {
      final result = truncateMiddle('abcdefghijklmn', 8);
      expect(result, 'abcd\u2026lmn');
      expect(result.length, lessThanOrEqualTo(8));
    });

    test('returns truncated ellipsis when maxLength < ellipsis.length', () {
      expect(truncateMiddle('abc', 0), '');
      final result = truncateMiddle('abc', 2, ellipsis: '...');
      expect(result.length, lessThanOrEqualTo(2));
      expect(result, '..');
    });

    test('accounts for custom ellipsis length and split rules', () {
      expect(truncateMiddle('abcdefghij', 7, ellipsis: '...'), 'ab...ij');
      expect(truncateMiddle('abcdef', 3), 'a\u2026f');
      expect(truncateMiddle('abcdefg', 4), 'ab\u2026g');
      expect(truncateMiddle('abcdef', 1, ellipsis: '\u2026'), '\u2026');
    });
  });
}