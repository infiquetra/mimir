/// Utility functions for string manipulation.

/// Truncates the middle of a string with an ellipsis, preserving the start and end.
///
/// If [input] length is less than or equal to [maxLength], returns [input] unchanged.
/// Otherwise, replaces the middle of the string with [ellipsis], keeping the start
/// and end visible such that the total length is less than or equal to [maxLength].
///
/// The [maxLength] parameter includes the length of the ellipsis.
/// If [maxLength] is shorter than [ellipsis], returns [ellipsis] truncated to [maxLength].
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abcd…lmn'`
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 3)` → `'a…f'*
library string_utils;

String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // Return unchanged if input already fits within maxLength
  if (input.length <= maxLength) {
    return input;
  }

  // Calculate available characters for visible content (excluding ellipsis)
  final availableVisibleChars = maxLength - ellipsis.length;
  
  // If maxLength is shorter than ellipsis, return truncated ellipsis
  if (availableVisibleChars <= 0) {
    return ellipsis.substring(0, maxLength);
  }

  // Distribute visible characters: start gets the extra character if odd
  final prefixLength = (availableVisibleChars + 1) ~/ 2;
  final suffixLength = availableVisibleChars ~/ 2;
  
  // Construct and return the truncated string
  return input.substring(0, prefixLength) +
      ellipsis +
      input.substring(input.length - suffixLength);
}