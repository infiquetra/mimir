/// Extension methods on List.
extension ChunkedList<T> on List<T> {
  /// Splits this list into consecutive sub-lists of at most [size] elements.
  ///
  /// The last chunk may be smaller than [size] if the list length is not
  /// evenly divisible.
  ///
  /// Each returned chunk is independent — mutating a chunk does not affect
  /// the original list.
  ///
  /// Throws [ArgumentError] if [size] is less than 1.
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'chunk size must be at least 1');
    }
    if (isEmpty) return <List<T>>[];
    final result = <List<T>>[];
    for (var start = 0; start < length; start += size) {
      final end = start + size < length ? start + size : length;
      result.add(sublist(start, end));
    }
    return result;
  }
}
