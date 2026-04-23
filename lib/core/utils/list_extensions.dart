/// Extension methods for List collections.
library list_extensions;

/// Extension that provides chunking capabilities to Lists.
extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive sub-lists of at most [size] elements.
  ///
  /// [size] must be >= 1; throws [ArgumentError] if not.
  /// 
  /// Returns an empty list if the source list is empty.
  /// The last chunk may be smaller than [size].
  /// 
  /// Each returned chunk is independent of the original list (modifying a chunk
  /// does not affect the original list).
  ///
  /// Examples:
  /// ```dart
  /// [1,2,3,4,5].chunked(2) // [[1,2],[3,4],[5]]
  /// [1,2,3].chunked(10)    // [[1,2,3]]
  /// [].chunked(3)           // []
  /// [1].chunked(1)          // [[1]]
  /// ```
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'must be >= 1');
    }

    if (isEmpty) {
      return [];
    }

    final List<List<T>> chunks = [];
    for (int i = 0; i < length; i += size) {
      final end = i + size < length ? i + size : length;
      // Using sublist creates independent lists
      chunks.add(sublist(i, end));
    }
    
    return chunks;
  }
}