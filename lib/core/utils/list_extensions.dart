// Extension methods on List for common collection operations.

extension ChunkedList<T> on List<T> {
  /// Splits this list into consecutive sub-lists of at most [size] elements.
  ///
  /// The last chunk may be smaller than [size] if the list length is not
  /// evenly divisible. Returned chunks are independent copies — mutating
  /// a chunk will not affect the original list.
  ///
  /// Throws [ArgumentError] if [size] is less than 1.
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'must be >= 1');
    }
    if (isEmpty) return [];

    final result = <List<T>>[];
    for (var start = 0; start < length; start += size) {
      final end = (start + size).clamp(0, length);
      result.add(sublist(start, end));
    }
    return result;
  }
}