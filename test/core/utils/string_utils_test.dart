import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when length is within maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('replaces the middle with the default ellipsis', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abc…lmn');
      expect(truncateMiddle('abcdefghijklmn', 8).length, lessThanOrEqualTo(8));
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('truncates to fit very small maxLength values', () {
      // 'a…f': available = 3 - 1 = 2, sideLength = 1; result = 'a…f'
      expect(truncateMiddle('abcdef', 3), 'a…f');
      // only the ellipsis fits
      expect(truncateMiddle('abcdef', 1), '…');
      // maxLength of 0: return empty string
      expect(truncateMiddle('abcdef', 0), '');
    });

    test('accounts for custom ellipsis length', () {
      // available = 10 - 3 = 7, sideLength = 3; result = 'abc...lmn'
      expect(truncateMiddle('abcdefghijklmn', 10, ellipsis: '...'), 'abc...lmn');
      expect(truncateMiddle('abcdefghijklmn', 10, ellipsis: '...').length, lessThanOrEqualTo(10));
      // ellipsis truncated to fit
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
    });
  });
}
