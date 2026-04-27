/// Extension utilities for [List].
library;

/// Splits a list into consecutive sub-lists of at most [size] elements.
extension ChunkedList<T> on List<T> {
  /// Returns a list of chunks, each of which is a new list containing up to
  /// [size] elements from the original list.
  ///
  /// Throws [ArgumentError] if [size] is less than 1.
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(
          size, 'size', 'Must be greater than or equal to 1');
    }

    if (isEmpty) {
      return <List<T>>[];
    }

    final chunks = <List<T>>[];
    for (var index = 0; index < length; index += size) {
      final end = index + size > length ? length : index + size;
      chunks.add(sublist(index, end));
    }

    return chunks;
  }
}
