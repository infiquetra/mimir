import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList', () {
    test('chunked splits a list into consecutive chunks', () {
      final List<int> list = [1, 2, 3, 4, 5];
      final List<List<int>> result = list.chunked(2);
      expect(result, [
        [1, 2],
        [3, 4],
        [5]
      ]);
    });

    test('chunked returns one chunk when size equals list length', () {
      final List<int> list = [1, 2, 3];
      final List<List<int>> result = list.chunked(3);
      expect(result, [
        [1, 2, 3]
      ]);
    });

    test('chunked returns one chunk when size exceeds list length', () {
      final List<int> list = [1, 2, 3];
      final List<List<int>> result = list.chunked(10);
      expect(result, [
        [1, 2, 3]
      ]);
    });

    test('chunked returns an empty list for an empty source list', () {
      final List<int> list = <int>[];
      final List<List<int>> result = list.chunked(3);
      expect(result, <List<int>>[]);
    });

    test('chunked returns a single-item chunk for a one-element list', () {
      final List<int> list = [1];
      final List<List<int>> result = list.chunked(1);
      expect(result, [
        [1]
      ]);
    });

    test('chunked throws ArgumentError when size is zero', () {
      final List<int> list = [1, 2, 3];
      expect(() => list.chunked(0), throwsArgumentError);
    });

    test('chunked throws ArgumentError when size is negative', () {
      final List<int> list = [1, 2, 3];
      expect(() => list.chunked(-1), throwsArgumentError);
    });

    test('chunked returns independent chunk lists', () {
      final List<int> list = [1, 2, 3, 4];
      final List<List<int>> result = list.chunked(2);
      
      // Mutate one of the chunks
      result[0][0] = 99;
      
      // Original list should remain unchanged
      expect(list, [1, 2, 3, 4]);
      
      // The result should reflect our mutation
      expect(result[0], [99, 2]);
      expect(result[1], [3, 4]);
    });
  });
}
