library list_extensions;

extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive sub-lists of at most [size] elements.
  ///
  /// The last chunk may be smaller than [size] if the list length is not
  /// evenly divisible by [size].
  ///
  /// Returns independent lists - mutating a chunk does not affect the
  /// original list.
  ///
  /// Throws [ArgumentError] if [size] is less than 1.
  ///
  /// Examples:
  /// - `[1, 2, 3, 4, 5].chunked(2)` → `[[1, 2], [3, 4], [5]]`
  /// - `[1, 2, 3].chunked(10)` → `[[1, 2, 3]]`
  /// - `[].chunked(3)` → `[]`
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'Must be greater than or equal to 1');
    }

    if (isEmpty) {
      return <List<T>>[];
    }

    final result = <List<T>>[];
    for (var start = 0; start < length; start += size) {
      final end = start + size < length ? start + size : length;
      result.add(sublist(start, end));
    }
    return result;
  }
}
