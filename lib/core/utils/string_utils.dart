/// Utility functions for string manipulation.
///
/// Provides helper functions for common string operations that are not
/// readily available in Dart's core library.
library mimir.core.utils.string_utils;

/// Truncates a string in the middle, replacing the removed portion with an ellipsis.
///
/// If the input string is shorter than or equal to [maxLength], it is returned
/// unchanged. Otherwise, the middle of the string is replaced with [ellipsis],
/// keeping the start and end portions visible.
///
/// The [maxLength] parameter includes the length of the ellipsis, so the
/// returned string will never exceed [maxLength] characters.
///
/// For example:
/// - truncateMiddle('hello', 10) returns 'hello'
/// - truncateMiddle('abcdefghijklmn', 8) returns 'abc…lmn'
/// - truncateMiddle('', 5) returns ''
/// - truncateMiddle('abcdef', 3) returns 'a…f' (design choice: favors visible
///   characters on both ends when possible)
///
/// When [maxLength] is shorter than the ellipsis length, the ellipsis itself
/// is truncated to fit within [maxLength].
///
/// When the visible character budget ([maxLength] - [ellipsis].length) is odd,
/// the extra visible character is consistently given to the start portion.
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // Return input unchanged if it's already short enough
  if (input.length <= maxLength) {
    return input;
  }

  // Ensure the ellipsis fits within maxLength
  final effectiveEllipsis = ellipsis.length <= maxLength
      ? ellipsis
      : ellipsis.substring(0, maxLength);

  // If even the truncated ellipsis doesn't fit, return it alone
  final visibleBudget = maxLength - effectiveEllipsis.length;
  if (visibleBudget <= 0) {
    return effectiveEllipsis;
  }

  // Split the visible budget, favoring start when odd
  final startCount = (visibleBudget + 1) ~/ 2;
  final endCount = visibleBudget ~/ 2;

  // Construct the result: start + ellipsis + end
 return input.substring(0, startCount) +
      effectiveEllipsis +
      input.substring(input.length - endCount);
}