/// Extension that adds utility methods to Lists.
extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive sub-lists of at most [size] elements.
  ///
  /// Throws [ArgumentError] if [size] is less than 1.
  ///
  /// Example:
  /// ```dart
  /// [1,2,3,4,5].chunked(2) // [[1,2],[3,4],[5]]
  /// [1,2,3].chunked(10)    // [[1,2,3]]
  /// [].chunked(3)          // []
  /// [1].chunked(1)         // [[1]]
  /// ```
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'Must be greater than or equal to 1');
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