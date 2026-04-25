extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive sub-lists of at most [size] elements.
  ///
  /// Returns a list of lists where each inner list contains up to [size] elements
  /// from the original list in the same order. The last chunk may be smaller
  /// than [size] if the list length is not evenly divisible by [size].
  ///
  /// Throws [ArgumentError] if [size] is less than 1.
  ///
  /// Examples:
  /// ```dart
  /// [1, 2, 3, 4, 5].chunked(2) // [[1, 2], [3, 4], [5]]
  /// [1, 2, 3].chunked(10)      // [[1, 2, 3]]
  /// [].chunked(3)              // []
  /// [1].chunked(1)             // [[1]]
  /// ```
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'Must be greater than 0');
    }

    if (isEmpty) {
      return <List<T>>[];
    }

    final List<List<T>> chunks = <List<T>>[];
    for (int i = 0; i < length; i += size) {
      final int end = (i + size < length) ? i + size : length;
      chunks.add(sublist(i, end));
    }

    return chunks;
  }
}