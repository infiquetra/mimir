import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when it already fits maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('a', 1), 'a');
      expect(truncateMiddle('', 5), '');
    });

    test('truncates the middle with the extra odd-budget character kept at the start', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('returns empty string for empty input', () {
      expect(truncateMiddle('', 5), '');
    });

    test('returns truncated ellipsis alone when maxLength is shorter than ellipsis', () {
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
      expect(truncateMiddle('abcdef', 1, ellipsis: '...'), '.');
    });

    test('counts the full ellipsis length toward maxLength', () {
      expect(truncateMiddle('abcdefghi', 5, ellipsis: '...'), 'a...i');
      // Verify length constraint is respected
      final result = truncateMiddle('abcdefghi', 5, ellipsis: '...');
      expect(result.length, lessThanOrEqualTo(5));
    });

    test('handles single character input', () {
      expect(truncateMiddle('a', 1), 'a');
      expect(truncateMiddle('ab', 1), '…');
    });
  });
}