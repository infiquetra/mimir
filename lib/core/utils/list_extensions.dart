library;

extension ChunkedList<T> on List<T> {
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'must be >= 1');
    }

    if (isEmpty) {
      return <List<T>>[];
    }

    final result = <List<T>>[];
    for (var start = 0; start < length; start += size) {
      final end = (start + size < length) ? start + size : length;
      result.add(sublist(start, end));
    }

    return result;
  }
}
