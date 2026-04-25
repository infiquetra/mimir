import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList.chunked', () {
    test('splits a list into consecutive chunks of the requested size', () {
      expect([1, 2, 3, 4, 5].chunked(2), [
        [1, 2],
        [3, 4],
        [5]
      ]);
    });

    test('returns one chunk when chunk size equals the list length', () {
      expect([1, 2, 3].chunked(3), [
        [1, 2, 3]
      ]);
    });

    test('returns one chunk when chunk size exceeds the list length', () {
      expect([1, 2, 3].chunked(10), [
        [1, 2, 3]
      ]);
    });

    test('returns an empty list for an empty source list', () {
      expect([].chunked(3), []);
    });

    test('returns a single-element chunk for a single-element list', () {
      expect([1].chunked(1), [
        [1]
      ]);
    });

    test('throws ArgumentError when size is 0', () {
      expect(() => [1, 2, 3].chunked(0), throwsArgumentError);
    });

    test('throws ArgumentError when size is negative', () {
      expect(() => [1, 2, 3].chunked(-1), throwsArgumentError);
    });

    test('returns independent chunk lists', () {
      final original = [1, 2, 3, 4];
      final chunks = original.chunked(2);
      // Mutate a chunk
      chunks[0][0] = 99;
      // Original should remain unchanged
      expect(original, [1, 2, 3, 4]);
    });
  });
}