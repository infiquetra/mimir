import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns input unchanged when it is shorter than maxLength', () {
      expect(truncateMiddle('hello', 10), 'hello');
    });

    test('returns input unchanged when it exactly matches maxLength', () {
      expect(truncateMiddle('hello', 5), 'hello');
    });

    test('replaces the middle while preserving start and end', () {
      expect(truncateMiddle('abcdefghijklmn', 8), 'abcd…lmn');
      expect(truncateMiddle('abcdefghijklmn', 8).length, lessThanOrEqualTo(8));
    });

    test('returns empty input unchanged', () {
      expect(truncateMiddle('', 5), '');
    });

    test('truncates to ellipsis when maxLength cannot fit visible characters',
        () {
      expect(truncateMiddle('abcdef', 1), '…');
      expect(truncateMiddle('abcdef', 0), '');
    });

    test('accounts for custom ellipsis length', () {
      expect(truncateMiddle('abcdefghijklmn', 9, ellipsis: '...'), 'abc...lmn');
      expect(truncateMiddle('abcdefghijklmn', 9, ellipsis: '...').length,
          lessThanOrEqualTo(9));
    });

    test('throws for negative maxLength', () {
      expect(() => truncateMiddle('abcdef', -1), throwsArgumentError);
    });
  });
}
