import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList.chunked', () {
    test('splits a list into consecutive chunks', () {
      final list = [1, 2, 3, 4, 5];
      final result = list.chunked(2);
      
      expect(result, [[1, 2], [3, 4], [5]]);
      
      // Verify independence: mutating a chunk doesn't affect original list
      result[0][0] = 999;
      expect(list, [1, 2, 3, 4, 5]); // Original list unchanged
    });

    test('returns one chunk when size equals list length', () {
      final list = [1, 2, 3];
      final result = list.chunked(3);
      
      expect(result, [[1, 2, 3]]);
    });

    test('returns one chunk when size exceeds list length', () {
      final list = [1, 2, 3];
      final result = list.chunked(10);
      
      expect(result, [[1, 2, 3]]);
    });

    test('returns empty list for empty input', () {
      final list = <int>[];
      final result = list.chunked(3);
      
      expect(result, []); // Empty list of lists
    });

    test('returns single-element chunk for size one', () {
      final list = [42];
      final result = list.chunked(1);
      
      expect(result, [[42]]);
    });

    test('throws ArgumentError when size is zero', () {
      final list = [1, 2, 3];
      
      expect(() => list.chunked(0), throwsArgumentError);
    });

    test('throws ArgumentError when size is negative', () {
      final list = [1, 2, 3];
      
      expect(() => list.chunked(-1), throwsArgumentError);
    });
  });
}