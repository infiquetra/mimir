import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList', () {
    test('chunks list into consecutive sub-lists of requested size', () {
      expect([1, 2, 3, 4, 5].chunked(2), [
        [1, 2],
        [3, 4],
        [5]
      ]);
    });

    test('returns one chunk when size equals list length', () {
      expect([1, 2, 3].chunked(3), [
        [1, 2, 3]
      ]);
    });

    test('returns one chunk when size is greater than list length', () {
      expect([1, 2, 3].chunked(10), [
        [1, 2, 3]
      ]);
    });

    test('returns empty list for empty input', () {
      expect(<int>[].chunked(3), <List<int>>[]);
    });

    test('returns single one-element chunk for single element list', () {
      expect([1].chunked(1), [
        [1]
      ]);
    });

    test('throws ArgumentError when size is zero', () {
      expect(() => [1, 2, 3].chunked(0), throwsArgumentError);
    });

    test('throws ArgumentError when size is negative', () {
      expect(() => [1, 2, 3].chunked(-1), throwsArgumentError);
    });

    test('returns chunks independent from the original list', () {
      final original = [1, 2, 3];
      final chunks = original.chunked(2);

      // Mutate the first chunk
      chunks.first[0] = 99;

      // Original should remain unchanged
      expect(original, [1, 2, 3]);
      // Chunk should reflect the mutation
      expect(chunks, [
        [99, 2],
        [3]
      ]);
    });
  });
}
