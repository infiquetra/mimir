import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList.chunked', () {
    test('happy path splits list into chunks of specified size', () {
      final input = [1, 2, 3, 4, 5];
      final result = input.chunked(2);
      expect(result, [[1, 2], [3, 4], [5]]);
    });

    test('chunk size equal to list length returns single chunk', () {
      final input = [1, 2, 3];
      final result = input.chunked(3);
      expect(result, [[1, 2, 3]]);
    });

    test('chunk size greater than list length returns single chunk', () {
      final input = [1, 2, 3];
      final result = input.chunked(10);
      expect(result, [[1, 2, 3]]);
    });

    test('empty list returns empty list', () {
      final input = <int>[];
      final result = input.chunked(3);
      expect(result, []);
    });

    test('single element with size 1 returns [[element]]', () {
      final input = [1];
      final result = input.chunked(1);
      expect(result, [[1]]);
    });

    test('throws ArgumentError when size is 0', () {
      final input = [1, 2, 3];
      expect(() => input.chunked(0), throwsArgumentError);
    });

    test('throws ArgumentError when size is negative', () {
      final input = [1, 2, 3];
      expect(() => input.chunked(-1), throwsArgumentError);
    });

    test('returned chunks are independent of original list', () {
      final input = [1, 2, 3, 4];
      final chunks = input.chunked(2);
      
      // Mutate the first element of the first chunk
      chunks.first[0] = 999;
      
      // Original list should be unchanged
      expect(input[0], 1);
      expect(chunks.first[0], 999);
    });

    test('returned chunks are independent of each other', () {
      final input = [1, 2, 3, 4];
      final chunks = input.chunked(2);
      
      // Mutate the first chunk
      chunks[0][0] = 999;
      
      // Second chunk should be unchanged
      expect(chunks[1][0], 3);
    });
  });
}
