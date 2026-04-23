import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('chunked', () {
    test('chunked splits a list into consecutive chunks', () {
      final original = [1, 2, 3, 4, 5];
      final result = original.chunked(2);

      expect(result, equals([[1, 2], [3, 4], [5]]));

      // Verify independence: mutating a returned chunk should not affect original
      result[0].add(999);
      expect(original, equals([1, 2, 3, 4, 5]));
    });

    test('chunked returns a single chunk when size equals list length',
        () {
      final result = [1, 2, 3].chunked(3);
      expect(result, equals([[1, 2, 3]]));
    });

    test('chunked returns a single chunk when size exceeds list length',
        () {
      final result = [1, 2, 3].chunked(10);
      expect(result, equals([[1, 2, 3]]));
    });

    test('chunked returns empty list for empty input', () {
      final result = [].chunked(3);
      expect(result, equals([]));
    });

    test('chunked returns single-element chunk for single-item list', () {
      final result = [1].chunked(1);
      expect(result, equals([[1]]));
    });

    test('chunked throws ArgumentError when size is zero', () {
      expect(() => [1, 2, 3].chunked(0), throwsArgumentError);
    });

    test('chunked throws ArgumentError when size is negative', () {
      expect(() => [1, 2, 3].chunked(-1), throwsArgumentError);
    });
  });
}
