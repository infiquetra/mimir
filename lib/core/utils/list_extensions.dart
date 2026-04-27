extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive sub-lists of at most [size] elements.
  ///
  /// Throws [ArgumentError] if [size] is less than 1.
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'must be greater than or equal to 1');
    }

    if (isEmpty) {
      return <List<T>>[];
    }

    final List<List<T>> chunks = [];
    for (int start = 0; start < length; start += size) {
      final int end = start + size < length ? start + size : length;
      chunks.add(sublist(start, end));
    }

    return chunks;
  }
}
