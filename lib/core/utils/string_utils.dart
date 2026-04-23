/// Utility functions for string manipulation.
library;

/// Truncates a string in the middle if it exceeds [maxLength].
///
/// If the string length is less than or equal to [maxLength], the original string is returned.
/// Otherwise, the middle part is replaced with [ellipsis] such that the resulting
/// string length is exactly [maxLength] (unless [maxLength] is less than [ellipsis]
/// length, in which case a truncated [ellipsis] is returned).
///
/// When calculating how many characters to keep from the start and end:
/// - The total budget for visible characters is `maxLength - ellipsis.length`.
/// - If this budget is odd, the extra character is assigned to the start.
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  if (input.length <= maxLength) {
    return input;
  }

  if (input.isEmpty) {
    return '';
  }

  if (maxLength <= 0) {
    return '';
  }

  if (maxLength <= ellipsis.length) {
    return ellipsis.substring(0, maxLength);
  }

  final visibleCharacters = maxLength - ellipsis.length;
  final startLength = (visibleCharacters + 1) ~/ 2;
  final endLength = visibleCharacters ~/ 2;

  final start = input.substring(0, startLength);
  final end = endLength > 0 ? input.substring(input.length - endLength) : '';

  return '$start$ellipsis$end';
}
