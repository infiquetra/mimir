import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns unchanged input when input length is within maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('replaces the middle while keeping start and end visible', () {
      // maxLength = 8, ellipsis = 1. budget = 7. side = 3. result length = 3+1+3 = 7 <= 8.
      expect(truncateMiddle('abcdefghijklmn', 8), 'abc…lmn');
    });

    test('returns empty string unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('uses documented small maxLength behavior', () {
      // maxLength = 3, ellipsis = 1. budget = 2. side = 1. result = 'a…f'
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('truncates ellipsis when maxLength is shorter than ellipsis', () {
      expect(truncateMiddle('abcdef', 2, ellipsis: '---'), '--');
      expect(truncateMiddle('abcdef', 0), '');
    });

    test('counts custom ellipsis length in maxLength budget', () {
      // maxLength = 9, ellipsis = 3. budget = 6. side = 3. result length = 3+3+3 = 9.
      expect(truncateMiddle('abcdefghijklmn', 9, ellipsis: '...'), 'abc...lmn');
      expect(truncateMiddle('abcdefghijklmn', 9, ellipsis: '...').length, lessThanOrEqualTo(9));
    });
  });
}
