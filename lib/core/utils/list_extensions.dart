/// Extension methods for [List] utilities.
library list_extensions;

/// Extension that adds chunking functionality to Lists.
extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive sub-lists of at most [size] elements.
  ///
  /// Throws an [ArgumentError] if [size] is less than 1.
  ///
  /// Example:
  /// ```dart
  /// final list = [1, 2, 3, 4, 5];
  /// final chunked = list.chunked(2);
  /// // chunked is [[1, 2], [3, 4], [5]]
  /// ```
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'must be >= 1');
    }

    if (isEmpty) {
      return [];
    }

    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      final end = i + size < length ? i + size : length;
      // Using sublist creates a new list, ensuring chunks are independent
      chunks.add(sublist(i, end));
    }

    return chunks;
  }
}
