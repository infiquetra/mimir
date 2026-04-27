import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList', () {
    test('splits list into consecutive chunks of requested size', () {
      expect(
          [1, 2, 3, 4, 5].chunked(2),
          equals([
            [1, 2],
            [3, 4],
            [5]
          ]));
    });

    test('returns one chunk when size equals list length', () {
      expect(
          [1, 2, 3].chunked(3),
          equals([
            [1, 2, 3]
          ]));
    });

    test('returns one chunk when size is greater than list length', () {
      expect(
          [1, 2, 3].chunked(10),
          equals([
            [1, 2, 3]
          ]));
    });

    test('returns empty list for empty input', () {
      expect(<int>[].chunked(3), equals(<List<int>>[]));
    });

    test('returns one single-element chunk for single-element input', () {
      expect(
          [1].chunked(1),
          equals([
            [1]
          ]));
    });

    test('throws ArgumentError when size is zero', () {
      expect(() => [1, 2, 3].chunked(0), throwsArgumentError);
    });

    test('returns chunks independent from the original list', () {
      final original = [1, 2, 3];
      final chunks = original.chunked(2);
      chunks.first[0] = 99;
      expect(original, equals([1, 2, 3]));
      expect(
          chunks,
          equals([
            [99, 2],
            [3]
          ]));
    });
  });
}
