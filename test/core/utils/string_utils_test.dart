import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns unchanged input when length is within maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('replaces the middle while keeping start and end visible', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
      expect(truncateMiddle('abcdefghijklmn', 7), 'abc…lmn');
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
      expect(truncateMiddle('', 0), '');
    });

    test('uses truncated ellipsis when maxLength is shorter than ellipsis', () {
      expect(truncateMiddle('abcdef', 2, ellipsis: '...'), '..');
      expect(truncateMiddle('abcdef', 0, ellipsis: '...'), '');
    });

    test('accounts for custom ellipsis length in output budget', () {
      expect(truncateMiddle('abcdefghijklmn', 8, ellipsis: '...'), 'abc...mn');
      expect(truncateMiddle('abcdef', 3), 'a…f');
    });

    test('throws ArgumentError when maxLength is negative', () {
      expect(() => truncateMiddle('abcdef', -1), throwsArgumentError);
    });
  });
}
