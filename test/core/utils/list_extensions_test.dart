import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList', () {
    test('splits a list into consecutive chunks of at most size elements', () {
      expect([1, 2, 3, 4, 5].chunked(2), [
        [1, 2],
        [3, 4],
        [5],
      ]);
    });

    test('returns a single chunk when size equals list length', () {
      expect([1, 2, 3].chunked(3), [
        [1, 2, 3],
      ]);
    });

    test('returns a single chunk when size exceeds list length', () {
      expect([1, 2, 3].chunked(10), [
        [1, 2, 3],
      ]);
    });

    test('returns an empty list for an empty source list', () {
      expect(<int>[].chunked(3), []);
    });

    test('returns a single-element chunk for a one-item list', () {
      expect([1].chunked(1), [
        [1],
      ]);
    });

    test('throws ArgumentError when size is 0', () {
      expect(() => [1, 2, 3].chunked(0), throwsArgumentError);
    });

    test('returns independent chunk lists', () {
      final original = [1, 2, 3, 4];
      final chunks = original.chunked(2);
      chunks[0][0] = 99;
      expect(original[0], equals(1));
    });
  });
}