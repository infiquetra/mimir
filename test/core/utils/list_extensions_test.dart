import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList', () {
    test('chunked splits a list into consecutive chunks', () {
      final result = [1, 2, 3, 4, 5].chunked(2);
      expect(
          result,
          equals([
            [1, 2],
            [3, 4],
            [5]
          ]));
    });

    test('chunked returns one chunk when size equals list length', () {
      final result = [1, 2, 3].chunked(3);
      expect(
          result,
          equals([
            [1, 2, 3]
          ]));
    });

    test('chunked returns one chunk when size exceeds list length', () {
      final result = [1, 2, 3].chunked(10);
      expect(
          result,
          equals([
            [1, 2, 3]
          ]));
    });

    test('chunked returns an empty list for an empty source list', () {
      final result = <int>[].chunked(3);
      expect(result, equals(<List<int>>[]));
    });

    test('chunked returns a single-item chunk for a one-element list', () {
      final result = [1].chunked(1);
      expect(
          result,
          equals([
            [1]
          ]));
    });

    test('chunked throws ArgumentError when size is zero', () {
      expect(() => [1, 2, 3].chunked(0), throwsArgumentError);
    });

    test('chunked throws ArgumentError when size is negative', () {
      expect(() => [1, 2, 3].chunked(-1), throwsArgumentError);
    });

    test('chunked returns independent chunk lists', () {
      final original = [1, 2, 3, 4];
      final result = original.chunked(2);
      result[0][0] = 99;
      expect(original, equals([1, 2, 3, 4]));
      expect(result[0][0], equals(99));
    });
  });
}
