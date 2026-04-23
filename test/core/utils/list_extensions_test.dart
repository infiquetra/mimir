import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('chunked', () {
    test('happy path: splits list into chunks of specified size', () {
      final list = [1, 2, 3, 4, 5];
      final result = list.chunked(2);
      expect(result, [
        [1, 2],
        [3, 4],
        [5]
      ]);
    });

    test('boundary: chunk size equals list length', () {
      final list = [1, 2, 3];
      final result = list.chunked(3);
      expect(result, [
        [1, 2, 3]
      ]);
    });

    test('boundary: chunk size greater than list length', () {
      final list = [1, 2, 3];
      final result = list.chunked(10);
      expect(result, [
        [1, 2, 3]
      ]);
    });

    test('empty list returns empty list', () {
      final list = <int>[];
      final result = list.chunked(3);
      expect(result, []);
    });

    test('single element with size 1', () {
      final list = [1];
      final result = list.chunked(1);
      expect(result, [
        [1]
      ]);
    });

    test('error case: size == 0 throws ArgumentError', () {
      final list = [1, 2, 3];
      expect(() => list.chunked(0), throwsA(isA<ArgumentError>()));
    });

    test('error case: size < 0 throws ArgumentError', () {
      final list = [1, 2, 3];
      expect(() => list.chunked(-1), throwsA(isA<ArgumentError>()));
    });

    test('returned chunks are independent from the original list', () {
      final list = [1, 2, 3, 4, 5];
      final result = list.chunked(2);

      // Mutate a returned chunk
      if (result.isNotEmpty) {
        result[0].add(999);
      }

      // Original list should be unchanged
      expect(list, [1, 2, 3, 4, 5]);

      // First chunk should have the additional element
      expect(result[0], [1, 2, 999]);
    });
  });
}
