import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when input length is within maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('truncates the middle while preserving start and end', () {
      final result = truncateMiddle('abcdefghijklmn', 8);
      expect(result, 'abc…lmn');
      expect(result.length <= 8, isTrue);
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('returns truncated ellipsis when maxLength is shorter than ellipsis', () {
      expect(truncateMiddle('abcdef', 1), '…');
      expect(truncateMiddle('abcdef', 0), '');
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
    });

    test('accounts for custom ellipsis length in maxLength', () {
      final result = truncateMiddle('abcdefghijklmn', 8, ellipsis: '...');
      expect(result, 'ab...mn');
      expect(result.length <= 8, isTrue);
    });

    test('uses documented design choice for very small maxLength', () {
      final result = truncateMiddle('abcdef', 3);
      expect(result, 'a…f');
      expect(result.length <= 3, isTrue);
    });
  });
}
