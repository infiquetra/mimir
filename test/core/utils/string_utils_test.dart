import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('returns unchanged string when input is shorter than maxLength', () {
      expect(truncateMiddle('hello', 10), equals('hello'));
      expect(truncateMiddle('a', 1), equals('a'));
      expect(truncateMiddle('', 5), equals(''));
    });

    test('truncates middle of long strings', () {
      // Example from notes: abcdefghijklmn (14 chars) with maxLength 8
      // Should keep 3 chars at start and end with 1 char ellipsis in middle
      final result = truncateMiddle('abcdefghijklmn', 8);
      expect(result.length, lessThanOrEqualTo(8));
      expect(result.startsWith('abc'), isTrue);
      expect(result.endsWith('lmn'), isTrue);
      expect(result.contains('…'), isTrue);
    });

    test('handles empty string', () {
      expect(truncateMiddle('', 5), equals(''));
      expect(truncateMiddle('', 0), equals(''));
    });

    test('handles maxLength shorter than ellipsis', () {
      // Custom multi-character ellipsis that's longer than maxLength
      expect(truncateMiddle('hello', 2, ellipsis: '---'), equals('--'));
      expect(truncateMiddle('world', 1, ellipsis: '...'), equals('.'));
      expect(truncateMiddle('test', 3, ellipsis: '....'), equals('...'));
    });

    test('ellipsis length counts toward maxLength', () {
      // With default ellipsis '…' (1 char) and maxLength 5
      // Should have 4 visible chars split 2+2
      final result = truncateMiddle('1234567890', 5);
      expect(result.length, equals(5));
      expect(result, equals('12…90'));
      
      // With 3-char ellipsis and maxLength 6
      // Should have 3 visible chars split 2+1
      final result2 = truncateMiddle('1234567890', 6, ellipsis: '...');
      expect(result2.length, equals(6));
      expect(result2, equals('12...0'));
    });

    test('documents design choice for short limits', () {
      // As documented in notes: truncateMiddle('abcdef', 3) should return 'a…f'
      // This gives 1 visible char on each side when ellipsis is 1 char long
      final result = truncateMiddle('abcdef', 3);
      expect(result.length, equals(3));
      expect(result, equals('a…f'));
      
      // Verify the pattern: startChar + ellipsis + endChar
      expect(result.startsWith('a'), isTrue);
      expect(result.endsWith('f'), isTrue);
      expect(result.contains('…'), isTrue);
    });
  });
}