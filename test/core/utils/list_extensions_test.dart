import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('chunked', () {
    test('returns consecutive chunks for a normal list', () {
      final result = [1, 2, 3, 4, 5].chunked(2);
      expect(result, [[1, 2], [3, 4], [5]]);
    });

    test('returns one chunk when size equals list length', () {
      final result = [1, 2, 3].chunked(3);
      expect(result, [[1, 2, 3]]);
    });

    test('returns one chunk when size exceeds list length', () {
      final result = [1, 2, 3].chunked(10);
      expect(result, [[1, 2, 3]]);
    });

    test('returns empty list for empty input', () {
      final result = <int>[].chunked(3);
      expect(result, []);
    });

    test('returns single-item chunk for single-element list', () {
      final result = [1].chunked(1);
      expect(result, [[1]]);
    });

    test('throws ArgumentError when size is 0', () {
      expect(() => [1, 2, 3].chunked(0), throwsArgumentError);
    });

    test('returned chunks are independent from original list', () {
      final original = [1, 2, 3, 4, 5];
      final chunks = original.chunked(2);
      
      // Mutate the first chunk
      chunks[0].add(99);
      
      // Original list should be unchanged
      expect(original, [1, 2, 3, 4, 5]);
      
      // Other chunks should be unchanged
      expect(chunks[1], [3, 4]);
      expect(chunks[2], [5]);
    });
  });
}
