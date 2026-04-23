/// Utility functions for string manipulation.
library string_utils;

/// Truncates a string in the middle with an ellipsis when it exceeds [maxLength].
///
/// If [input.length] is less than or equal to [maxLength], returns [input] unchanged.
/// Otherwise, replaces the middle portion with [ellipsis] such that the result
/// length is less than or equal to [maxLength].
///
/// When [maxLength] - [ellipsis.length] leaves an odd visible character budget,
/// the extra character is allocated to the start of the string.
///
/// Examples:
/// ```dart
/// truncateMiddle('hello', 10) // 'hello'
/// truncateMiddle('abcdefghijklmn', 8) // 'abcd…lmn'
/// truncateMiddle('', 5) // ''
/// truncateMiddle('abcdef', 3) // 'a…f'
/// truncateMiddle('abcdef', 0) // ''
/// truncateMiddle('abcdefghij', 7, ellipsis: '...') // 'ab...ij'
/// truncateMiddle('abcdef', 2, ellipsis: '...') // '..'
/// ```
///
/// Args:
///   input: The string to potentially truncate
///   maxLength: Maximum allowed length of the output string (including ellipsis)
///   ellipsis: String to insert in place of the middle portion (defaults to '…')
///
/// Returns: A string with length <= [maxLength]
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // Guard clause for non-positive maxLength
  if (maxLength <= 0) return '';
  
  // If input fits within maxLength, return unchanged
  if (input.length <= maxLength) return input;
  
  // If maxLength is smaller than ellipsis, return truncated ellipsis
  if (maxLength < ellipsis.length) return ellipsis.substring(0, maxLength);
  
  // Calculate the visible character budget (excluding ellipsis)
  final visibleCharacterBudget = maxLength - ellipsis.length;
  
  // If no visible characters can be shown, return just the ellipsis
  if (visibleCharacterBudget <= 0) return ellipsis;
  
  // Split the visible character budget
  // For odd budgets, give the extra character to the start (leading)
  final leadingCount = (visibleCharacterBudget + 1) ~/ 2;
  final trailingCount = visibleCharacterBudget ~/ 2;
  
  // Build the result string
  final leading = input.substring(0, leadingCount);
  final trailing = input.substring(input.length - trailingCount);
  
  return '$leading$ellipsis$trailing';
}