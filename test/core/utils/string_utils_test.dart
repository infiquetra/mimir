import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns unchanged input when length is within maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('replaces the middle with the default ellipsis', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abc…lmn');
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('returns truncated ellipsis when maxLength is shorter than ellipsis', () {
      expect(truncateMiddle('abcdef', 0), '');
      expect(truncateMiddle('abcdef', 1), '…');
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
    });

    test('counts custom ellipsis length toward maxLength', () {
      expect(truncateMiddle('abcdefghijklmn', 9, ellipsis: '...'), 'abc...lmn');
      expect(truncateMiddle('abcdefghijklmn', 10, ellipsis: '[...]'), 'ab[...]mn');
    });
  });
}
