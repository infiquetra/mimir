import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/utils/list_extensions.dart';

void main() {
  group('ChunkedList', () {
    group('chunked', () {
      test('returns consecutive chunks of the requested size', () {
        final list = [1, 2, 3, 4, 5];
        final result = list.chunked(2);
        
        expect(result, [
          [1, 2],
          [3, 4],
          [5]
        ]);
        
        // Verify chunks are independent of original list
        result[0][0] = 999;
        expect(list[0], 1); // Original unchanged
      });
      
      test('returns a single chunk when chunk size equals list length', () {
        final list = [1, 2, 3];
        final result = list.chunked(3);
        
        expect(result, [
          [1, 2, 3]
        ]);
      });
      
      test('returns a single chunk when chunk size exceeds list length', () {
        final list = [1, 2, 3];
        final result = list.chunked(10);
        
        expect(result, [
          [1, 2, 3]
        ]);
      });
      
      test('returns an empty list for an empty source list', () {
        final list = <int>[];
        final result = list.chunked(3);
        
        expect(result, []);
      });
      
      test('returns the single element when chunk size is one', () {
        final list = [42];
        final result = list.chunked(1);
        
        expect(result, [
          [42]
        ]);
      });
      
      test('throws ArgumentError when chunk size is zero', () {
        final list = [1, 2, 3];
        
        expect(() => list.chunked(0), throwsArgumentError);
      });
      
      test('throws ArgumentError when chunk size is negative', () {
        final list = [1, 2, 3];
        
        expect(() => list.chunked(-1), throwsArgumentError);
      });
    });
  });
}