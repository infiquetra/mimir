/// Utility functions for string manipulation.
library string_utils;

/// Truncates the middle of a string with an ellipsis.
///
/// If [input] length is less than or equal to [maxLength], returns [input] unchanged.
/// Otherwise, replaces the middle of the string with [ellipsis], keeping the start
/// and end visible.
///
/// The [maxLength] parameter includes the length of the ellipsis.
/// The return value length will be less than or equal to [maxLength].
///
/// Handles edge cases:
/// - Empty string: returns empty string
/// - MaxLength shorter than ellipsis: returns ellipsis truncated to maxLength
/// - MaxLength <= 0: returns empty string
///
/// For balanced truncation, the visible parts are equal in length. If the 
/// available budget for visible characters (maxLength - ellipsis.length) is odd, 
/// one character of the budget is intentionally left unused to ensure symmetry.
///
/// Example:
/// ```dart
/// truncateMiddle('hello', 10); // 'hello'
/// truncateMiddle('abcdefghijklmn', 8); // 'abc…lmn'
/// truncateMiddle('', 5); // ''
/// truncateMiddle('abcdef', 3); // 'a…f'
/// ```
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // Fast path for strings that don't need truncation
  if (input.length <= maxLength) {
    return input;
  }

  // Handle zero or negative maxLength
  if (maxLength <= 0) {
    return '';
  }

  final ellipsisLength = ellipsis.length;

  // If maxLength is shorter than the ellipsis, return truncated ellipsis
  if (maxLength <= ellipsisLength) {
    return ellipsis.substring(0, maxLength);
  }

  // Calculate balanced visible halves
  final availableChars = maxLength - ellipsisLength;
  final sideLength = availableChars ~/ 2;

  // Build the result: start + ellipsis + end
  return '${input.substring(0, sideLength)}'
      '$ellipsis'
      '${input.substring(input.length - sideLength)}';
}
