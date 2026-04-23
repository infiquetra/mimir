/// Extension methods for List operations.
extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive sub-lists of at most [size] elements.
  ///
  /// Throws an [ArgumentError] if [size] is less than 1.
  ///
  /// Examples:
  /// ```dart
  /// [1,2,3,4,5].chunked(2); // [[1,2], [3,4], [5]]
  /// [1,2,3].chunked(10);    // [[1,2,3]]
  /// [].chunked(3);          // []
  /// [1].chunked(1);         // [[1]]
  /// ```
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'Must be greater than or equal to 1');
    }

    // Return empty list for empty source
    if (isEmpty) {
      return [];
    }

    // Create chunks by walking the list in increments of size
    final chunks = <List<T>>[];
    for (int i = 0; i < length; i += size) {
      // Calculate end index, ensuring it doesn't exceed list length
      final end = i + size < length ? i + size : length;
      // Use sublist to create independent chunks (copies, not views)
      chunks.add(sublist(i, end));
    }

    return chunks;
  }
}