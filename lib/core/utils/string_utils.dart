// Utility functions for string manipulation.

/// Truncates a long string by replacing its middle with an ellipsis,
/// preserving characters from both the start and end.
///
/// If [input] is already [maxLength] or shorter, it is returned unchanged.
/// The total length of the returned string (including [ellipsis]) will
/// never exceed [maxLength].
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abc…lmn'`
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 3)` → `'a…f'`
String truncateMiddle(
  String input,
  int maxLength, {
  String ellipsis = '…',
}) {
  if (input.length <= maxLength) {
    return input;
  }

  if (maxLength <= 0) {
    return '';
  }

  if (maxLength < ellipsis.length) {
    return ellipsis.substring(0, maxLength);
  }

  if (maxLength == ellipsis.length) {
    return ellipsis;
  }

  final availableVisibleChars = maxLength - ellipsis.length;
  final sideLength = availableVisibleChars ~/ 2;

  final start = input.substring(0, sideLength);
  final end = input.substring(input.length - sideLength);

  return '$start$ellipsis$end';
}
