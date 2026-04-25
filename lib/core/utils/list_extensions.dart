/// Extension methods for List operations.
extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive sub-lists of at most [size] elements.
  ///
  /// Throws an [ArgumentError] if [size] is less than 1.
  ///
  /// Examples:
  /// ```dart
  /// [1,2,3,4,5].chunked(2) // [[1,2],[3,4],[5]]
  /// [1,2,3].chunked(10)    // [[1,2,3]]
  /// [].chunked(3)          // []
  /// [1].chunked(1)         // [[1]]
  /// ```
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'must be greater than or equal to 1');
    }

    if (isEmpty) {
      return [];
    }

    final result = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      final end = i + size < length ? i + size : length;
      // Create a new list to ensure independence of chunks
      result.add(sublist(i, end));
    }
    return result;
  }
}