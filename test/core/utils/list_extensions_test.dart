import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('chunked', () {
    test('splits a list into consecutive chunks', () {
      expect([1, 2, 3, 4, 5].chunked(2), equals([
        [1, 2],
        [3, 4],
        [5]
      ]));
    });

    test('returns a single chunk when chunk size matches list length', () {
      expect([1, 2, 3].chunked(3), equals([
        [1, 2, 3]
      ]));
    });

    test('returns a single chunk when chunk size exceeds list length', () {
      expect([1, 2, 3].chunked(10), equals([
        [1, 2, 3]
      ]));
    });

    test('returns an empty list for empty input', () {
      expect(<int>[].chunked(3), equals([]));
    });

    test('returns a single-element chunk for a single-item list', () {
      expect([1].chunked(1), equals([
        [1]
      ]));
    });

    test('throws ArgumentError when size is zero', () {
      expect(() => [1, 2, 3].chunked(0), throwsArgumentError);
    });

    test('throws ArgumentError when size is negative', () {
      expect(() => [1, 2, 3].chunked(-1), throwsArgumentError);
    });

    test('returns independent chunk lists', () {
      final originalList = [1, 2, 3, 4];
      final chunks = originalList.chunked(2);
      final firstChunk = chunks[0];

      // Mutate the chunk
      firstChunk[0] = 999;

      // Original list should be unchanged
      expect(originalList, equals([1, 2, 3, 4]));
      // The chunk should reflect the mutation
      expect(firstChunk, equals([999, 2]));
    });
  });
}