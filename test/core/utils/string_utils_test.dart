import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when input length is less than maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
    });

    test('returns input unchanged when input length equals maxLength', () {
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('replaces the middle with the default ellipsis', () {
      final result = truncateMiddle('abcdefghijklmn', 8);
      expect(result, 'abc…lmn');
      expect(result.length, lessThanOrEqualTo(8));
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('keeps both ends visible for very small maxLength when possible', () {
      final result = truncateMiddle('abcdef', 3);
      expect(result, 'a…f');
      expect(result.length, lessThanOrEqualTo(3));
    });

    test('returns truncated ellipsis alone when maxLength is shorter than ellipsis', () {
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
    });

    test('accounts for custom ellipsis length in maxLength', () {
      final result = truncateMiddle('abcdefghijklmn', 10, ellipsis: '[...]');
      expect(result, 'ab[...]mn');
      expect(result.length, lessThanOrEqualTo(10));
    });

    test('throws ArgumentError when maxLength is negative', () {
      expect(() => truncateMiddle('abcdef', -1), throwsArgumentError);
    });
  });
}