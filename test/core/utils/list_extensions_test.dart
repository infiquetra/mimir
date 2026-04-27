import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList.chunked', () {
    test('splits list into consecutive chunks', () {
      final result = [1, 2, 3, 4, 5].chunked(2);
      expect(result, [[1, 2], [3, 4], [5]]);
    });

    test('returns one chunk when size equals list length', () {
      final result = [1, 2, 3].chunked(3);
      expect(result, [[1, 2, 3]]);
    });

    test('returns one chunk when size is greater than list length', () {
      final result = [1, 2, 3].chunked(10);
      expect(result, [[1, 2, 3]]);
    });

    test('returns empty list for empty input', () {
      final result = <int>[].chunked(3);
      expect(result, <List<int>>[]);
    });

    test('returns single-element chunk for single-element list', () {
      final result = [1].chunked(1);
      expect(result, [[1]]);
    });

    test('throws ArgumentError when size is zero', () {
      expect(() => [1, 2, 3].chunked(0), throwsArgumentError);
    });

    test('returned chunks are independent from the original list', () {
      final original = [1, 2, 3];
      final chunks = original.chunked(2);
      chunks.first[0] = 99;
      expect(original, [1, 2, 3]);
    });
  });
}
