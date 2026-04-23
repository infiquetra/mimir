import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList.chunked', () {
    test('happy path: splits into consecutive chunks', () {
      final input = [1, 2, 3, 4, 5];
      final result = input.chunked(2);
      expect(result, equals([[1, 2], [3, 4], [5]]));
    });

    test('boundary: chunk size equals list length', () {
      final input = [1, 2, 3];
      final result = input.chunked(3);
      expect(result, equals([[1, 2, 3]]));
    });

    test('boundary: chunk size exceeds list length', () {
      final input = [1, 2, 3];
      final result = input.chunked(10);
      expect(result, equals([[1, 2, 3]]));
    });

    test('empty list: returns empty list', () {
      final input = <int>[];
      final result = input.chunked(3);
      expect(result, equals(<List<int>>[]));
    });

    test('single element: returns a single chunk with one element', () {
      final input = [1];
      final result = input.chunked(1);
      expect(result, equals([[1]]));
    });

    test('throws ArgumentError when size is 0', () {
      final input = [1, 2, 3];
      expect(() => input.chunked(0), throwsArgumentError);
    });

    test('throws ArgumentError when size is negative', () {
      final input = [1, 2, 3];
      expect(() => input.chunked(-1), throwsArgumentError);
    });

    test('returned chunks are independent from the original list', () {
      final input = [1, 2, 3, 4];
      final chunks = input.chunked(2);
      
      // Mutate the first chunk
      chunks[0][0] = 99;
      
      expect(input[0], equals(1), reason: 'Original list should not be affected by mutating the chunk');
      expect(chunks[0][0], equals(99), reason: 'Chunk should be mutated independently');
    });
  });
}
