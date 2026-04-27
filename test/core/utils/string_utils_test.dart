import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when length is within maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('replaces the middle with an ellipsis', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abc…lmn');
      expect(truncateMiddle('abcdefghijklmn', 8).length, lessThanOrEqualTo(8));
    });

    test('returns empty string unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('truncates ellipsis when maxLength is shorter than ellipsis', () {
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
      expect(truncateMiddle('abcdef', 0), '');
    });

    test('includes custom ellipsis length in maxLength budget', () {
      expect(truncateMiddle('abcdefghijklmn', 9, ellipsis: '...'), 'abc...lmn');
      expect(truncateMiddle('abcdefghijklmn', 9, ellipsis: '...').length, lessThanOrEqualTo(9));
    });
  });
}