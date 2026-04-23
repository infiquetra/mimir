library;

/// Extension methods for List<T> utility functions.

/// Extension that provides chunking functionality on lists.
extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive sub-lists of at most `size` elements.
  ///
  /// Returns a list of chunks where each chunk contains up to `size` elements.
  /// The last chunk may contain fewer elements if the list length is not
  /// evenly divisible by `size`.
  ///
  /// Examples:
  /// - `[1,2,3,4,5].chunked(2)` → `[[1,2],[3,4],[5]]`
  /// - `[1,2,3].chunked(10)` → `[[1,2,3]]`
  /// - `[].chunked(3)` → `[]`
  /// - `[1].chunked(1)` → `[[1]]`
  ///
  /// Throws [ArgumentError] if `size` is less than 1.
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(
        size,
        'size',
        'must be >= 1',
      );
    }

    if (isEmpty) {
      return [];
    }

    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      final end = (i + size < length) ? i + size : length;
      chunks.add(sublist(i, end));
    }
    return chunks;
  }
}
