library list_extensions;

extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive sub-lists of at most [size] elements.
  ///
  /// Throws an [ArgumentError] if [size] is less than 1.
  ///
  /// Example:
  /// ```dart
  /// final list = [1, 2, 3, 4, 5];
  /// final chunks = list.chunked(2);
  /// // chunks is [[1, 2], [3, 4], [5]]
  /// ```
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(
          size, 'size', 'Must be greater than or equal to 1');
    }

    if (isEmpty) {
      return [];
    }

    final chunks = <List<T>>[];
    for (int i = 0; i < length; i += size) {
      final end = i + size < length ? i + size : length;
      chunks.add(sublist(i, end));
    }
    return chunks;
  }
}
