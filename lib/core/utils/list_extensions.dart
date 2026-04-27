/// Extension methods for List<T>.
extension ChunkedList<T> on List<T> {
  /// Splits this list into consecutive chunks of at most `size` elements.
  ///
  /// Example:
  /// ```dart
  /// [1, 2, 3, 4, 5].chunked(2)  // → [[1, 2], [3, 4], [5]]
  /// [1, 2, 3].chunked(10)       // → [[1, 2, 3]]
  /// [].chunked(3)               // → []
  /// ```
  ///
  /// throws ArgumentError if size < 1.
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'must be >= 1');
    }

    final chunks = <List<T>>[];
    for (var start = 0; start < length; start += size) {
      final end = (start + size < length) ? start + size : length;
      chunks.add(List<T>.of(sublist(start, end)));
    }
    return chunks;
  }
}
