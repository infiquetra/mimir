import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('should return unchanged short strings', () {
      expect(truncateMiddle('hello', 10), equals('hello'));
      expect(truncateMiddle('', 5), equals(''));
      expect(truncateMiddle('a', 5), equals('a'));
    });

    test('should truncate middle of long strings', () {
      // For truncateMiddle('abcdefghijklmn', 8): 
      // visibleLength = 8 - 1 = 7
      // frontLength = (7 + 1) ~/ 2 = 4
      // backLength = 7 ~/ 2 = 3
      // Result: 'abcd' + '…' + 'lmn' = 'abcd…lmn'
      expect(truncateMiddle('abcdefghijklmn', 8), equals('abcd…lmn'));
      
      // For truncateMiddle('abcdefghijklmnop', 10):
      // visibleLength = 10 - 1 = 9
      // frontLength = (9 + 1) ~/ 2 = 5
      // backLength = 9 ~/ 2 = 4
      // Result: 'abcde' + '…' + 'mnop' = 'abcde…mnop'
      expect(truncateMiddle('abcdefghijklmnop', 10), equals('abcde…mnop'));
    });

    test('should handle empty input', () {
      expect(truncateMiddle('', 5), equals(''));
    });

    test('should handle single character input', () {
      expect(truncateMiddle('a', 5), equals('a'));
    });

  test('should handle maxLength too small edge case', () {
    expect(truncateMiddle('hello', 1), equals('…'));
    expect(truncateMiddle('hello', 0), equals(''));
    // When maxLength is shorter than ellipsis, should truncate ellipsis
    expect(truncateMiddle('hello', 2, ellipsis: '...'), equals('..'));
  });
  
  test('should reject negative maxLength', () {
    expect(() => truncateMiddle('hello', -1), throwsArgumentError);
    expect(() => truncateMiddle('', -5), throwsArgumentError);
  });

    test('should consider ellipsis length', () {
      // For truncateMiddle('hello world', 5, ellipsis: '...'):
      // visibleLength = 5 - 3 = 2
      // frontLength = (2 + 1) ~/ 2 = 1
      // backLength = 2 ~/ 2 = 1
      // Result: 'h' + '...' + 'd' = 'h...d'
      expect(truncateMiddle('hello world', 5, ellipsis: '...'), equals('h...d'));
      
      // For truncateMiddle('abcdef', 4, ellipsis: '..'):
      // visibleLength = 4 - 2 = 2
      // frontLength = (2 + 1) ~/ 2 = 1
      // backLength = 2 ~/ 2 = 1
      // Result: 'a' + '..' + 'f' = 'a..f'
      expect(truncateMiddle('abcdef', 4, ellipsis: '..'), equals('a..f'));
    });

    test('should follow documented design choice', () {
      // For truncateMiddle('abcdef', 3), visibleLength = 3 - 1 = 2
      // frontLength = (2 + 1) ~/ 2 = 1, backLength = 2 ~/ 2 = 1
      // So we keep 1 char from front ('a') + ellipsis + 1 char from back ('f')
      expect(truncateMiddle('abcdef', 3), equals('a…f'));
    });

    test('should handle odd visible length with front-heavy policy', () {
      // For truncateMiddle('abcdefghijk', 6), visibleLength = 6 - 1 = 5
      // frontLength = (5 + 1) ~/ 2 = 3, backLength = 5 ~/ 2 = 2
      // So we keep 3 chars from front ('abc') + ellipsis + 2 chars from back ('jk')
      expect(truncateMiddle('abcdefghijk', 6), equals('abc…jk'));
    });

    test('should handle even visible length appropriately', () {
      // For truncateMiddle('abcdefghij', 7), visibleLength = 7 - 1 = 6
      // frontLength = (6 + 1) ~/ 2 = 3, backLength = 6 ~/ 2 = 3
      // So we keep 3 chars from front ('abc') + ellipsis + 3 chars from back ('hij')
      expect(truncateMiddle('abcdefghij', 7), equals('abc…hij'));
    });

    test('should handle visible length of 1 correctly', () {
      // For truncateMiddle('abc', 2), visibleLength = 2 - 1 = 1
      // frontLength = (1 + 1) ~/ 2 = 1, backLength = 1 ~/ 2 = 0
      // So we keep 1 char from front ('a') + ellipsis + 0 chars from back ('')
      expect(truncateMiddle('abc', 2), equals('a…'));
    });
  });
}