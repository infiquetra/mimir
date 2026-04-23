import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('chunked', () {
    test('splits a list into consecutive chunks of the requested size', () {
      expect([1, 2, 3, 4, 5].chunked(2), [[1, 2], [3, 4], [5]]);
    });

    test('returns one chunk when chunk size equals list length', () {
      expect([1, 2, 3].chunked(3), [[1, 2, 3]]);
    });

    test('returns one chunk when chunk size exceeds list length', () {
      expect([1, 2, 3].chunked(10), [[1, 2, 3]]);
    });

    test('returns an empty list for an empty source list', () {
      expect([].chunked(3), []);
    });

    test('returns a single-element chunk for a single-element list', () {
      expect([1].chunked(1), [[1]]);
    });

    test('throws ArgumentError when size is zero', () {
      expect(() => [1, 2, 3].chunked(0), throwsArgumentError);
    });

    test('returned chunks are independent of the source list', () {
      final source = [1, 2, 3, 4, 5];
      final chunks = source.chunked(2);
      chunks[0][0] = 999;
      expect(source, [1, 2, 3, 4, 5]);
    });
  });
}
