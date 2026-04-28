// Utility functions for string manipulation.

/// Truncates [input] to at most [maxLength] characters, replacing the middle
/// with [ellipsis] when the string exceeds [maxLength].
///
/// - If [input].length <= [maxLength], returns [input] unchanged.
/// - Otherwise, keeps an equal number of characters from the start and end,
///   separated by [ellipsis].
/// - The returned string length is always <= [maxLength].
/// - When [maxLength] - [ellipsis].length is odd, one character of capacity
///   is left unused to keep the result balanced (e.g. 'a…f' for maxLength=3).
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abc…lmn'`
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 3)` → `'a…f'`
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  if (maxLength < 0) {
    throw ArgumentError.value(
      maxLength,
      'maxLength',
      'must be non-negative',
    );
  }

  // Fits unchanged
  if (input.length <= maxLength) return input;

  // Ellipsis alone exceeds or fills the budget
  if (ellipsis.length >= maxLength) {
    return ellipsis.substring(0, maxLength);
  }

  // Balanced middle truncation
  final visibleCharsPerSide = (maxLength - ellipsis.length) ~/ 2;
  return '${input.substring(0, visibleCharsPerSide)}$ellipsis${input.substring(input.length - visibleCharsPerSide)}';
}
