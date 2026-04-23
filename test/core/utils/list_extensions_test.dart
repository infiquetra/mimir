import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList.chunked', () {
    test('chunks list into multiple chunks of given size', () {
      // Happy path: [1,2,3,4,5] with size 2
      final result = [1, 2, 3, 4, 5].chunked(2);
      expect(result, [[1, 2], [3, 4], [5]]);
    });

    test('handles boundary where chunk size equals list length', () {
      // Size equals list length - single chunk containing all elements
      final result = [1, 2, 3].chunked(3);
      expect(result, [[1, 2, 3]]);
    });

    test('handles boundary where chunk size is greater than list length', () {
      // Size larger than list - single chunk with all elements
      final result = [1, 2, 3].chunked(10);
      expect(result, [[1, 2, 3]]);
    });

    test('returns empty list for empty input', () {
      final result = <int>[].chunked(3);
      expect(result, []);
    });

    test('handles single element list with size 1', () {
      final result = [1].chunked(1);
      expect(result, [[1]]);
    });

    test('throws ArgumentError when size is 0', () {
      expect(() => [1, 2, 3].chunked(0), throwsArgumentError);
    });

    test('proves returned chunks are independent copies', () {
      // Chunk the list, modify a returned chunk, verify original is unchanged
      final original = [1, 2, 3, 4, 5];
      final chunks = original.chunked(2);
      
      // Modify the first chunk
      chunks[0][0] = 999;
      
      // Original list should be unchanged
      expect(original[0], 1);
      expect(original[1], 2);
    });
  });
}
