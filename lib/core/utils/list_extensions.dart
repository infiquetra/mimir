library;

/// Utility extension methods for List operations.

/// Extension on List<T> providing chunked operations.
extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive sub-lists of at most [size] elements.
  ///
  /// The last chunk may be smaller than [size] if the list length is not
  /// evenly divisible by [size].
  ///
  /// If [size] is less than 1, throws [ArgumentError].
  ///
  /// Examples:
  /// - `[1,2,3,4,5].chunked(2)` → `[[1,2],[3,4],[5]]`
  /// - `[1,2,3].chunked(10)` → `[[1,2,3]]`
  /// - `[].chunked(3)` → `[]`
  /// - `[1].chunked(1)` → `[[1]]`
  List<List<T>> chunked(int size) {
    // Validate input
    if (size < 1) {
      throw ArgumentError('size must be >= 1, got $size');
    }

    // Empty list returns empty list
    if (isEmpty) {
      return [];
    }

    // Generate chunks using sublist - each sublist is a new list instance
    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      final end = (i + size).clamp(0, length);
      chunks.add(sublist(i, end));
    }
    return chunks;
  }
}
