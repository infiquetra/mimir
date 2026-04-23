/// Utility extension for splitting lists into chunks.
extension ChunkedList<T> on List<T> {
  /// Splits this list into consecutive sub-lists of at most [size] elements.
  ///
  /// Returns a list of chunks, each containing up to [size] elements.
  /// The final chunk may have fewer than [size] elements if the original
  /// list length is not a multiple of [size].
  ///
  /// Throws an [ArgumentError] if [size] is less than 1.
  ///
  /// Examples:
  /// ```dart
  /// [1, 2, 3, 4, 5].chunked(2) // [[1, 2], [3, 4], [5]]
  /// [1, 2, 3].chunked(10)       // [[1, 2, 3]]
  /// [].chunked(3)               // []
  /// [1].chunked(1)              // [[1]]
  /// ```
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError('size must be >= 1, but was $size');
    }

    if (isEmpty) {
      return <List<T>>[];
    }

    final result = <List<T>>[];
    for (var start = 0; start < length; start += size) {
      final end = start + size < length ? start + size : length;
      result.add(sublist(start, end));
    }
    return result;
  }
}
