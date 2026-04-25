// Utility functions for String manipulation.

/// Truncates a string by replacing the middle portion with an ellipsis
/// if its length exceeds [maxLength].
///
/// The [maxLength] includes the length of the [ellipsis].
/// If the input length is less than or equal to [maxLength], it is returned unchanged.
///
/// If [maxLength] is less than the length of [ellipsis], the ellipsis
/// itself is truncated to [maxLength].
///
/// When the remaining budget for visible characters ([maxLength] - [ellipsis].length)
/// is odd, the extra character is assigned to the prefix.
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abcd…lmn'`
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 3)` → `'a…f'`
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  if (input.length <= maxLength) {
    return input;
  }

  if (maxLength <= 0) {
    return '';
  }

  if (maxLength < ellipsis.length) {
    return ellipsis.substring(0, maxLength);
  }

  final availableVisibleChars = maxLength - ellipsis.length;
  // If availableVisibleChars is odd, distribute the extra char to the prefix.
  final prefixCount = (availableVisibleChars + 1) ~/ 2;
  final suffixCount = availableVisibleChars - prefixCount;

  final prefix = input.substring(0, prefixCount);
  final suffix = input.substring(input.length - suffixCount);

  return '$prefix$ellipsis$suffix';
}
