/// Extensions for [List] collections.
extension ChunkedList<T> on List<T> {
  /// Splits this list into consecutive sub-lists of at most [size] elements.
  ///
  /// The returned chunks are independent copies - mutating a chunk will not
  /// affect the original list.
  ///
  /// Throws [ArgumentError] if [size] is less than 1.
  ///
  /// Example:
  /// ```dart
  /// [1, 2, 3, 4, 5].chunked(2) // [[1, 2], [3, 4], [5]]
  /// [1, 2, 3].chunked(10) // [[1, 2, 3]]
  /// [].chunked(3) // []
  /// ```
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError('size must be >= 1, was $size');
    }

    if (isEmpty) {
      return [];
    }

    final result = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      final end = (i + size < length) ? i + size : length;
      result.add(sublist(i, end));
    }

    return result;
  }
}
