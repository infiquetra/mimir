import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('chunked', () {
    test('splits a list into consecutive chunks', () {
      expect([1, 2, 3, 4, 5].chunked(2), [
        [1, 2],
        [3, 4],
        [5]
      ]);
      expect([1, 2, 3, 4, 5, 6].chunked(3), [
        [1, 2, 3],
        [4, 5, 6]
      ]);
      expect([1, 2, 3].chunked(2), [
        [1, 2],
        [3]
      ]);
    });

    test('returns a single chunk when size equals list length', () {
      expect([1, 2, 3].chunked(3), [
        [1, 2, 3]
      ]);
    });

    test('returns a single chunk when size exceeds list length', () {
      expect([1, 2, 3].chunked(10), [
        [1, 2, 3]
      ]);
    });

    test('returns an empty list for empty input', () {
      expect(<int>[].chunked(3), []);
    });

    test('returns a single-element chunk for a one-item list', () {
      expect([42].chunked(1), [
        [42]
      ]);
    });

    test('returns independent chunk lists', () {
      final original = [1, 2, 3, 4];
      final chunks = original.chunked(2);

      expect(chunks, [
        [1, 2],
        [3, 4]
      ]);

      // Modify a chunk and ensure the original list is unchanged
      chunks[0][0] = 99;
      expect(original, [1, 2, 3, 4]);

      // Also ensure modifying the original list does not affect the chunk
      original[0] = 100;
      expect(chunks[0], [99, 2]);
    });

    test('throws ArgumentError when size is zero', () {
      expect(() => [1, 2, 3].chunked(0), throwsArgumentError);
      expect(() => [].chunked(0), throwsArgumentError);
    });

    test('throws ArgumentError when size is negative', () {
      expect(() => [1, 2, 3].chunked(-1), throwsArgumentError);
      expect(() => [].chunked(-5), throwsArgumentError);
    });
  });
}
