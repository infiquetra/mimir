import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList.chunked', () {
    test('happy path: splits list into specified sizes', () {
      final list = [1, 2, 3, 4, 5];
      final result = list.chunked(2);
      expect(result, [[1, 2], [3, 4], [5]]);
    });

    test('mutation safety: returned chunks are independent copies', () {
      final list = [1, 2, 3, 4];
      final result = list.chunked(2);
      
      // Mutate a chunk
      result[0][0] = 99;
      
      expect(list[0], 1, reason: 'Original list should not be mutated');
    });

    test('boundary: chunk size equals list length', () {
      final list = [1, 2, 3];
      final result = list.chunked(3);
      expect(result, [[1, 2, 3]]);
    });

    test('boundary: chunk size exceeds list length', () {
      final list = [1, 2, 3];
      final result = list.chunked(10);
      expect(result, [[1, 2, 3]]);
    });

    test('empty list returns empty list', () {
      final list = <int>[];
      final result = list.chunked(3);
      expect(result, <List<int>>[]);
    });

    test('single element list', () {
      final list = [1];
      final result = list.chunked(1);
      expect(result, [[1]]);
    });

    test('throws ArgumentError when size is 0', () {
      final list = [1, 2, 3];
      expect(() => list.chunked(0), throwsA(isA<ArgumentError>()));
    });

    test('throws ArgumentError when size is negative', () {
      final list = [1, 2, 3];
      expect(() => list.chunked(-1), throwsA(isA<ArgumentError>()));
    });
  });
}
