import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList.chunked', () {
    test('splits a list into consecutive chunks of the requested size', () {
      final list = [1, 2, 3, 4, 5];
      final result = list.chunked(2);

      expect(result, equals([[1, 2], [3, 4], [5]]));

      // Verify chunk independence: mutating a returned chunk should not affect the original list
      if (result.isNotEmpty) {
        result[0].add(999);
      }
      expect(list, equals([1, 2, 3, 4, 5]));
    });

    test('returns a single chunk when size equals the list length', () {
      final list = [1, 2, 3];
      final result = list.chunked(3);

      expect(result, equals([[1, 2, 3]]));
    });

    test('returns a single chunk when size exceeds the list length', () {
      final list = [1, 2, 3];
      final result = list.chunked(10);

      expect(result, equals([[1, 2, 3]]));
    });

    test('returns an empty list for an empty source list', () {
      final list = <int>[];
      final result = list.chunked(3);

      expect(result, equals(<List<int>>[]));
    });

    test('returns a single-element chunk for a one-element list with size 1', () {
      final list = [1];
      final result = list.chunked(1);

      expect(result, equals([[1]]));
    });

    test('throws ArgumentError when size is zero', () {
      final list = [1, 2, 3];
      expect(() => list.chunked(0), throwsArgumentError);
    });
  });
}
