import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('should return unchanged short strings', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('', 5), '');
      expect(truncateMiddle('a', 1), 'a');
    });

    test('should truncate middle of long strings', () {
      // With odd budget, extra char goes to front (start): (visibleBudget + 1) ~/ 2
      // maxLength=8, budget=7: front=4, back=3 = 'abcd…lmn' (4+1+3=8)
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
      // maxLength=10, budget=9: front=5, back=4 = 'abcde…mnop' (5+1+4=10)
      expect(truncateMiddle('abcdefghijklmnop', 10), 'abcde…mnop');
    });

    test('should handle empty input', () {
      expect(truncateMiddle('', 5), '');
    });

    test('should handle maxLength too small edge case', () {
      expect(truncateMiddle('abcdef', 1), '…');
      expect(truncateMiddle('abcdef', 2), '…');
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('should consider ellipsis length', () {
      // maxLength=4, budget=3: front=2, back=1 = 'ab…f' (2+1+1=4)
      expect(truncateMiddle('abcdef', 4), 'ab…f');
      // maxLength=5, budget=4: front=2, back=2 = 'ab…ef' (2+1+2=5)
      expect(truncateMiddle('abcdef', 5), 'ab…ef');
    });

    test('should handle multi-character ellipsis', () {
      // Using 3-char ellipsis '...'
      // maxLength=6, budget=3: front=2, back=1 = 'ab...h' (2+3+1=6) - takes last char 'h'
      expect(truncateMiddle('abcdefgh', 6, ellipsis: '...'), 'ab...h');
    });

    test('should handle the documented design choice for truncateMiddle(\'abcdef\', 3)', () {
      // As documented in the function example: budget=2, front=1, back=1 = 'a…f'
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });
  });
}
