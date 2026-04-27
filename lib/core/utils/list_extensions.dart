/// Extension methods for List operations.
library;

/// Extension that adds chunking functionality to List.
extension ChunkedList<T> on List<T> {
  /// Splits this list into consecutive sub-lists of at most [size] elements.
  ///
  /// The [size] must be greater than or equal to 1.
  /// Throws [ArgumentError] if [size] is less than 1.
  ///
  /// Returns an empty list if this list is empty.
  /// The last chunk may be smaller than [size] if the list length
  /// is not evenly divisible by [size].
  ///
  /// Each returned chunk is an independent list; mutating a chunk
  /// does not affect the original list.
  ///
  /// Example:
  /// ```dart
  /// [1, 2, 3, 4, 5].chunked(2); // [[1, 2], [3, 4], [5]]
  /// ```
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(
          size, 'size', 'must be greater than or equal to 1');
    }

    final result = <List<T>>[];
    for (var start = 0; start < length; start += size) {
      final end = (start + size) > length ? length : start + size;
      result.add(sublist(start, end));
    }
    return result;
  }
}
