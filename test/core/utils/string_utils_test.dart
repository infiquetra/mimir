import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns unchanged input when length is within maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test(
        'replaces the middle with the default ellipsis while keeping both ends '
        'visible', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abc…lmn');
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
      expect(truncateMiddle('', 0), '');
    });

    test('truncates the ellipsis alone when maxLength is too small', () {
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
      expect(truncateMiddle('abcdef', 0), '');
    });

    test('accounts for custom ellipsis length in the output length', () {
      final result = truncateMiddle('abcdefghijklmn', 8, ellipsis: '...');
      expect(result, 'ab...mn');
      expect(result.length, lessThanOrEqualTo(8));
    });
  });
}
