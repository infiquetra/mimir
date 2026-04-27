extension ChunkedList<T> on List<T> {
  /// Splits this list into consecutive sub-lists of at most [size] elements each.
  ///
  /// Returns a list of lists where each sub-list (except possibly the last)
  /// has exactly [size] elements. The last chunk may be smaller if the
  /// source list length is not evenly divisible by [size].
  ///
  /// [size] must be greater than or equal to `1`.
  /// Throws an [ArgumentError] if [size] is less than `1`.
  ///
  /// If the source list is empty, returns an empty list.
  ///
  /// The returned chunks are independent copies; modifying a returned chunk
  /// will not affect the original list.
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'Must be greater than or equal to 1');
    }

    if (isEmpty) {
      return <List<T>>[];
    }

    final List<List<T>> chunks = <List<T>>[];
    for (int start = 0; start < length; start += size) {
      final int end = start + size < length ? start + size : length;
      chunks.add(sublist(start, end));
    }
    return chunks;
  }
}