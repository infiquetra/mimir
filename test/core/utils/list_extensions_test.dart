import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList', () {
    group('chunked', () {
      test('splits list into consecutive chunks of requested size', () {
        expect([1, 2, 3, 4, 5].chunked(2), [
          [1, 2],
          [3, 4],
          [5]
        ]);
      });

      test('returns one chunk when chunk size equals list length', () {
        expect([1, 2, 3].chunked(3), [
          [1, 2, 3]
        ]);
      });

      test('returns one chunk when chunk size exceeds list length', () {
        expect([1, 2, 3].chunked(10), [
          [1, 2, 3]
        ]);
      });

      test('returns empty list for empty source list', () {
        expect(<int>[].chunked(3), []);
      });

      test('returns single-item chunk for single-element list', () {
        expect([42].chunked(1), [
          [42]
        ]);
      });

      test('throws ArgumentError when size is zero', () {
        expect(() => [1, 2, 3].chunked(0), throwsArgumentError);
      });

      test('throws ArgumentError when size is negative', () {
        expect(() => [1, 2, 3].chunked(-1), throwsArgumentError);
      });

      test('returned chunks are independent from original list', () {
        final originalList = [1, 2, 3, 4];
        final chunks = originalList.chunked(2);
        
        // Mutate a chunk
        chunks[0][0] = 99;
        
        // Original list should be unchanged
        expect(originalList, [1, 2, 3, 4]);
      });
    });
  });
}