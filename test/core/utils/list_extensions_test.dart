import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList.chunked', () {
    test('splits list into consecutive chunks of requested size', () {
      final input = [1, 2, 3, 4, 5];
      final result = input.chunked(2);
      expect(result, [[1, 2], [3, 4], [5]]);
    });

    test('returns one chunk when size equals list length', () {
      final input = [1, 2, 3];
      final result = input.chunked(3);
      expect(result, [[1, 2, 3]]);
    });

    test('returns one chunk when size is greater than list length', () {
      final input = [1, 2, 3];
      final result = input.chunked(10);
      expect(result, [[1, 2, 3]]);
    });

    test('returns empty list for empty input', () {
      final input = <int>[];
      final result = input.chunked(3);
      expect(result, <List<int>>[]);
    });

    test('returns single chunk for single element list', () {
      final input = [1];
      final result = input.chunked(1);
      expect(result, [[1]]);
    });

    test('throws ArgumentError when size is zero', () {
      expect(() => [1, 2, 3].chunked(0), throwsA(isA<ArgumentError>()));
    });

    test('returns chunks independent from original list', () {
      final original = [1, 2, 3, 4];
      final chunks = original.chunked(2);

      chunks[0][0] = 99;

      expect(original, [1, 2, 3, 4]);
      expect(chunks, [[99, 2], [3, 4]]);
    });
  });
}
