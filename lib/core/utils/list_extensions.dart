extension ChunkedList<T> on List<T> {
  /// Splits this list into consecutive sub-lists of at most [size] elements.
  ///
  /// Returns a list of lists where each inner list contains at most [size]
  /// elements from the original list, in order. The last chunk may be smaller
  /// than [size] if the original list length is not evenly divisible.
  ///
  /// Each returned chunk is an independent list (mutating one chunk does not
  /// affect the original list or other chunks).
  ///
  /// Throws [ArgumentError] if [size] is less than 1.
  ///
  /// Examples:
  ///   [1, 2, 3, 4, 5].chunked(2) → [[1, 2], [3, 4], [5]]
  ///   [1, 2, 3].chunked(10) → [[1, 2, 3]]
  ///   [].chunked(3) → []
  ///   [1].chunked(1) → [[1]]
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError('Size must be greater than 0', 'size');
    }

    if (isEmpty) {
      return <List<T>>[];
    }

    final result = <List<T>>[];
    for (var start = 0; start < length; start += size) {
      final end = (start + size > length) ? length : start + size;
      result.add(sublist(start, end));
    }

    return result;
  }
}