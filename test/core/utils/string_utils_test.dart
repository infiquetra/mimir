import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/string_utils.dart';

void main() {
  group('truncateMiddle', () {
    test('unchanged short strings', () {
      expect(truncateMiddle('hello', 10), equals('hello'));
      expect(truncateMiddle('a', 1), equals('a'));
      expect(truncateMiddle('', 5), equals(''));
    });

    test('middle truncation', () {
      final result = truncateMiddle('abcdefghijklmn', 8);
      expect(result.length, lessThanOrEqualTo(8));
      expect(result.startsWith('abc'), isTrue);
      expect(result.endsWith('lmn'), isTrue);
      expect(result.contains('…'), isTrue);
    });

    test('empty input', () {
      expect(truncateMiddle('', 5), equals(''));
      expect(truncateMiddle('', 0), equals(''));
    });

    test('maxLength-too-small edge case', () {
      // When maxLength is shorter than ellipsis, return truncated ellipsis
      expect(truncateMiddle('hello', 2, ellipsis: '---'), equals('--'));
      expect(truncateMiddle('world', 1, ellipsis: '...'), equals('.'));
    });

    test('ellipsis length consideration', () {
      // Custom ellipsis should count toward maxLength
      final result = truncateMiddle('abcdefghij', 6, ellipsis: '...');
      expect(result.length, lessThanOrEqualTo(6));
      expect(result.contains('...'), isTrue);
      
      // Verify we can still see some characters from start and end
      final noEllipsis = result.replaceAll('...', '');
      expect(noEllipsis.isNotEmpty, isTrue);
    });

    test('documented short-limit design choice', () {
      // For truncateMiddle('abcdef', 3), we expect 'a…f'
      // This preserves one visible character on each side
      final result = truncateMiddle('abcdef', 3);
      expect(result.length, equals(3));
      expect(result.startsWith('a'), isTrue);
      expect(result.endsWith('f'), isTrue);
      expect(result.contains('…'), isTrue);
    });
  });
}