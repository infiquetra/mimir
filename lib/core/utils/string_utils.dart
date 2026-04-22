/// Utility functions for string manipulation.
///
/// Contains helper functions for transforming and formatting strings
/// in various ways.

/// Truncates a string by removing characters from the middle and replacing
/// them with an ellipsis.
///
/// If [input].length <= [maxLength], returns [input] unchanged.
/// Otherwise, computes [visibleLength] = [maxLength] - [ellipsis].length.
/// If truncation is required and [visibleLength] <= 0, returns 
/// [ellipsis.substring](0, [maxLength]).
/// If truncation is required and [visibleLength] > 0, splits the visible 
/// characters between the front and back of [input] with a front-heavy policy:
/// [frontLength] = ([visibleLength] + 1) ~/ 2, [backLength] = [visibleLength] ~/ 2.
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abcd…lmn'`
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 3)` → `'a…f'`
///
/// Parameters:
/// - [input]: The string to truncate
/// - [maxLength]: Maximum length of the result including ellipsis
/// - [ellipsis]: The string to use as ellipsis (default: '…')
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // If input is already short enough, return unchanged
  if (input.length <= maxLength) {
    return input;
  }

  // Calculate how many visible characters we can show
  final visibleLength = maxLength - ellipsis.length;

  // If we can't even fit the ellipsis, return a truncated ellipsis
  if (visibleLength <= 0) {
    return ellipsis.substring(0, maxLength);
  }

  // Split the visible characters with front-heavy policy for odd lengths
  final frontLength = (visibleLength + 1) ~/ 2;
  final backLength = visibleLength ~/ 2;

  // Build the result
  final front = input.substring(0, frontLength);
  final back = backLength > 0 ? input.substring(input.length - backLength) : '';

  return '$front$ellipsis$back';
}