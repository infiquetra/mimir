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

    test('returns an empty list for an empty source list', () {
      expect(<int>[].chunked(3), []);
    });

    test('returns a single-element chunk for a one-item list', () {
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

    test('returns independent chunk lists', () {
      final originalList = [1, 2, 3, 4, 5];
      final chunks = originalList.chunked(2);
      
      // Mutate the first chunk
      if (chunks.isNotEmpty) {
        chunks[0].add(99);
      }
      
      // Original list should be unchanged
      expect(originalList, [1, 2, 3, 4, 5]);
    });
  });
}