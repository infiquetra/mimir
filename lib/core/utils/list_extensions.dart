extension ChunkedList<T> on List<T> {
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError('size must be >= 1, got $size');
    }

    if (isEmpty) {
      return [];
    }

    final result = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      final end = i + size > length ? length : i + size;
      result.add(sublist(i, end));
    }
    return result;
  }
}
