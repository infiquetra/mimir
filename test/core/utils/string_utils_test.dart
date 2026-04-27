import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('should return short strings unchanged', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('should truncate the middle of long strings', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abc…lmn');
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('should return empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('should return truncated ellipsis when maxLength is too small', () {
      expect(truncateMiddle('abcdef', 1), '…');
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
      expect(truncateMiddle('abcdef', 0), '');
    });

    test('should include custom ellipsis length in maxLength budget', () {
      expect(truncateMiddle('abcdefghijklmn', 8, ellipsis: '...'), 'ab...mn');
      expect(
        truncateMiddle('abcdefghijklmn', 8, ellipsis: '...').length,
        lessThanOrEqualTo(8),
      );
    });
  });
}
