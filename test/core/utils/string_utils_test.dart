import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when shorter than maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
    });

    test('returns input unchanged when equal to maxLength', () {
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('truncates the middle while keeping start and end visible', () {
      final result = truncateMiddle('abcdefghijklmn', 8);
      expect(result, 'abc…lmn');
      expect(result.length, lessThanOrEqualTo(8));
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('returns truncated ellipsis when maxLength is shorter than ellipsis',
        () {
      final result = truncateMiddle('abcdef', 2, ellipsis: '...');
      expect(result, '..');
      expect(result.length, lessThanOrEqualTo(2));
    });

    test('uses custom ellipsis length when calculating output length', () {
      final result = truncateMiddle('abcdefghijklmn', 9, ellipsis: '...');
      expect(result, 'abc...lmn');
      expect(result.length, lessThanOrEqualTo(9));
    });

    test('returns an empty string when truncating to non-positive maxLength',
        () {
      expect(truncateMiddle('abcdef', 0), '');
      expect(truncateMiddle('abcdef', -1), '');
    });
  });
}
