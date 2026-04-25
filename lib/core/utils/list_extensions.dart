/// Extension for chunking a list into consecutive sub-lists.
extension ChunkedList<T> on List<T> {
  /// Splits the list into consecutive sub-lists of at most [size] elements.
  ///
  /// Each chunk is a fresh list independent of the original.
  ///
  /// Throws [ArgumentError] if [size] is less than 1.
  ///
  /// Examples:
  /// - `[1,2,3,4,5].chunked(2)` → `[[1,2],[3,4],[5]]`
  /// - `[1,2,3].chunked(10)` → `[[1,2,3]]`
  /// - `[].chunked(3)` → `[]`
  /// - `[1].chunked(1)` → `[[1]]`
  List<List<T>> chunked(int size) {
    if (size < 1) {
      throw ArgumentError('size must be at least 1', 'size');
    }
    if (isEmpty) {
      return [];
    }
    final result = <List<T>>[];
    for (var start = 0; start < length; start += size) {
      final end = start + size < length ? start + size : length;
      result.add(sublist(start, end));
    }
    return result;
  }
}
