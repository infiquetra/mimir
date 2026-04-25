/// Extension methods for [List].
extension ChunkedList<T> on List<T> {
  /// Splits this list into consecutive sub-lists of at most [size] elements.
  ///
  /// The last chunk may be smaller than [size] if the list length is not
  /// evenly divisible by [size].
  ///
  /// Throws [ArgumentError] if [size] is less than 1.
  ///
  /// Returns an empty list if this list is empty.
  ///
  /// Each returned chunk is an independent copy (mutating a chunk does not
  /// affect the original list).
  ///
  /// Example:
  /// ```dart
  /// [1, 2, 3, 4, 5].chunked(2); // [[1, 2], [3, 4], [5]]
  /// [1, 2, 3].chunked(10);      // [[1, 2, 3]]
  /// [].chunked(3);              // []
  /// [1].chunked(1);             // [[1]]
  /// ```
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError('Size must be >= 1, got $size');
    }

    if (isEmpty) {
      return <List<T>>[];
    }

    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      final end = (i + size < length) ? i + size : length;
      chunks.add(sublist(i, end));
    }

    return chunks;
  }
}
