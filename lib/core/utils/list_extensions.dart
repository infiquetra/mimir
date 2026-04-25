/// Extension methods on [List<T>] for collection operations.
extension ChunkedList<T> on List<T> {
  /// Splits this list into consecutive sub-lists of at most [size] elements.
  ///
  /// Returns a new list containing independent chunk lists. Mutating a
  /// returned chunk does not affect the original list or other chunks.
  ///
  /// ## Examples
  /// ```dart
  /// [1, 2, 3, 4, 5].chunked(2) // [[1, 2], [3, 4], [5]]
  /// [1, 2, 3].chunked(10)      // [[1, 2, 3]]
  /// [].chunked(3)              // []
  /// [1].chunked(1)             // [[1]]
  /// ```
  ///
  /// ## Throws
  /// [ArgumentError] if [size] is less than 1.
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError('size must be >= 1, got $size');
    }

    if (isEmpty) {
      return [];
    }

    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      final end = i + size < length ? i + size : length;
      chunks.add(sublist(i, end));
    }
    return chunks;
  }
}
