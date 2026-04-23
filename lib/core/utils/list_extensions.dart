extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive sub-lists of at most [size] elements.
  ///
  /// Throws [ArgumentError] if [size] is less than 1.
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError('Chunk size must be at least 1');
    }

    if (isEmpty) {
      return [];
    }

    final List<List<T>> chunks = [];
    for (var i = 0; i < length; i += size) {
      chunks.add(sublist(i, i + size > length ? length : i + size));
    }

    return chunks;
  }
}
