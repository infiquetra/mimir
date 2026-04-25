import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList', () {
    test('chunked splits a list into consecutive chunks', () {
      final List<int> list = [1, 2, 3, 4, 5];
      final List<List<int>> result = list.chunked(2);
      expect(result, [[1, 2], [3, 4], [5]]);
    });

    test('chunked returns one chunk when size equals list length', () {
      final List<int> list = [1, 2, 3];
      final List<List<int>> result = list.chunked(3);
      expect(result, [[1, 2, 3]]);
    });

    test('chunked returns one chunk when size exceeds list length', () {
      final List<int> list = [1, 2, 3];
      final List<List<int>> result = list.chunked(10);
      expect(result, [[1, 2, 3]]);
    });

    test('chunked returns an empty list for an empty source list', () {
      final List<int> list = [];
      final List<List<int>> result = list.chunked(3);
      expect(result, []);
    });

    test('chunked returns a single-item chunk for a one-element list', () {
      final List<int> list = [42];
      final List<List<int>> result = list.chunked(1);
      expect(result, [[42]]);
    });

    test('chunked throws ArgumentError when size is zero', () {
      final List<int> list = [1, 2, 3];
      expect(() => list.chunked(0), throwsArgumentError);
    });

    test('chunked returns independent chunks (mutating a chunk does not affect original list)', () {
      final List<int> list = [1, 2, 3, 4, 5];
      final List<List<int>> chunks = list.chunked(2);
      
      // Mutate the first chunk
      chunks[0][0] = 999;
      
      // Original list should remain unchanged
      expect(list, [1, 2, 3, 4, 5]);
      
      // The chunk should reflect the mutation
      expect(chunks[0], [999, 2]);
    });
  });
}