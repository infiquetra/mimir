extension ChunkedList<T> on List<T> {
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError('chunk size must be >= 1, but was $size');
    }

    if (isEmpty) {
      return [];
    }

    final result = <List<T>>[];
    for (var start = 0; start < length; start += size) {
      final end = (start + size).clamp(0, length);
      result.add(sublist(start, end));
    }

    return result;
  }
}