import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList', () {
    test('chunked splits a list into consecutive chunks', () {
      expect(
        [1, 2, 3, 4, 5].chunked(2),
        [
          [1, 2],
          [3, 4],
          [5]
        ],
      );
    });

    test('chunked returns one chunk when size equals list length', () {
      expect(
        [1, 2, 3].chunked(3),
        [
          [1, 2, 3]
        ],
      );
    });

    test('chunked returns one chunk when size exceeds list length', () {
      expect(
        [1, 2, 3].chunked(10),
        [
          [1, 2, 3]
        ],
      );
    });

    test('chunked returns an empty list for an empty source list', () {
      expect(
        <int>[].chunked(3),
        <List<int>>[],
      );
    });

    test('chunked returns a single-item chunk for a one-element list', () {
      expect(
        [1].chunked(1),
        [
          [1]
        ],
      );
    });

    test('chunked throws ArgumentError when size is zero', () {
      expect(
        () => [1, 2, 3].chunked(0),
        throwsArgumentError,
      );
    });

    test('chunked returns independent chunk lists', () {
      final list = [1, 2, 3, 4];
      final result = list.chunked(2);
      result[0][0] = 99;
      expect(list, [1, 2, 3, 4]);
      expect(result[0], [99, 2]);
    });
  });
}
