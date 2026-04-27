import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns unchanged input when length is within maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('replaces the middle while keeping start and end visible', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abc…lmn');
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('truncates ellipsis alone when maxLength is too small', () {
      expect(truncateMiddle('abcdef', 0), '');
      expect(truncateMiddle('abcdef', 1), '…');
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
    });

    test('accounts for custom ellipsis length in the maximum length', () {
      final result = truncateMiddle('abcdefghijklmn', 10, ellipsis: '...');
      expect(result, 'abc...lmn');
      expect(result.length, lessThanOrEqualTo(10));
    });

    test('throws for negative maxLength', () {
      expect(() => truncateMiddle('abcdef', -1), throwsArgumentError);
    });
  });
}