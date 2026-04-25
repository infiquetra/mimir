import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList', () {
    test('chunked splits a list into consecutive chunks', () {
      final list = [1, 2, 3, 4, 5];
      final result = list.chunked(2);
      expect(result, [[1, 2], [3, 4], [5]]);
    });

    test('chunked returns one chunk when size equals list length', () {
      final list = [1, 2, 3];
      final result = list.chunked(3);
      expect(result, [[1, 2, 3]]);
    });

    test('chunked returns one chunk when size exceeds list length', () {
      final list = [1, 2, 3];
      final result = list.chunked(10);
      expect(result, [[1, 2, 3]]);
    });

    test('chunked returns an empty list for an empty source list', () {
      final list = <int>[];
      final result = list.chunked(3);
      expect(result, []);
    });

    test('chunked returns a single-item chunk for a one-element list', () {
      final list = [1];
      final result = list.chunked(1);
      expect(result, [[1]]);
    });

    test('chunked throws ArgumentError when size is zero', () {
      final list = [1, 2, 3];
      expect(() => list.chunked(0), throwsArgumentError);
    });

    test('chunked throws ArgumentError when size is negative', () {
      final list = [1, 2, 3];
      expect(() => list.chunked(-1), throwsArgumentError);
    });

    test('chunked returns independent chunk lists', () {
      final list = [1, 2, 3, 4];
      final result = list.chunked(2);
      
      // Modify a chunk
      result[0][0] = 999;
      
      // Original list should be unchanged
      expect(list[0], 1);
    });
  });
}
