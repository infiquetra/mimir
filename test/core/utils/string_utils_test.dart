import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when length is within maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('replaces the middle while preserving prefix and suffix', () {
      // Input length 14, maxLength 8, ellipsis '…' (len 1)
      // availableVisibleChars = 7. Prefix 4, Suffix 3.
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
    });

    test('returns empty string for empty input', () {
      expect(truncateMiddle('', 5), '');
    });

    test('returns truncated ellipsis when maxLength is shorter than ellipsis', () {
      // ellipsis is '...', length 3. maxLength is 2.
      expect(truncateMiddle('some long string', 2, ellipsis: '...'), '..');
      expect(truncateMiddle('some long string', 1, ellipsis: '...'), '.');
      expect(truncateMiddle('some long string', 0, ellipsis: '...'), '');
    });

    test('counts custom ellipsis length against maxLength', () {
      // Input 'abcdefghij' (10), maxLength 7, ellipsis '...' (3)
      // availableVisibleChars = 4. Prefix 2, Suffix 2.
      expect(truncateMiddle('abcdefghij', 7, ellipsis: '...'), 'ab...ij');
    });

    test('assigns the odd leftover visible character to the prefix consistently', () {
      // Input length 10, maxLength 6, ellipsis '…' (1)
      // availableVisibleChars = 5. Prefix 3, Suffix 2.
      expect(truncateMiddle('abcdefghij', 6), 'abc…ij');
      
      // Input length 10, maxLength 4, ellipsis '…' (1)
      // availableVisibleChars = 3. Prefix 2, Suffix 1.
      expect(truncateMiddle('abcdefghij', 4), 'ab…j');
    });

    test('handles maxLength exactly equal to ellipsis length', () {
      expect(truncateMiddle('abcdef', 1, ellipsis: '…'), '…');
      expect(truncateMiddle('abcdef', 3, ellipsis: '...'), '...');
    });
    
    test('documented design choice for small maxLength', () {
      // truncateMiddle('abcdef', 3) -> 'a…f'
      // availableVisibleChars = 2. Prefix 1, Suffix 1.
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });
  });
}
