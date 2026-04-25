/// Utility functions for string manipulation.
library string_utils;

/// Truncates the middle of a string with an ellipsis when it exceeds [maxLength].
///
/// If [input] length is less than or equal to [maxLength], returns [input] unchanged.
/// Otherwise, replaces the middle of the string with [ellipsis], keeping the start
/// and end visible.
///
/// The [maxLength] includes the length of the ellipsis.
///
/// Example:
/// ```dart
/// truncateMiddle('hello', 10); // 'hello'
/// truncateMiddle('abcdefghijklmn', 8); // 'abc…lmn'
/// truncateMiddle('', 5); // ''
/// truncateMiddle('abcdef', 3); // 'a…f'
/// ```
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // If input is short enough, return unchanged
  if (input.length <= maxLength) {
    return input;
  }

  // Calculate visible character budget (not counting ellipsis)
  final visibleLength = maxLength - ellipsis.length;
  
  // If insufficient visible characters to show both start and end meaningfully,
  // return ellipsis truncated to maxLength
  if (visibleLength < 2) {
    return ellipsis.substring(0, maxLength.clamp(0, ellipsis.length));
  }

  // Split visible characters between front and back:
  // When visibleLength is odd, give the extra char to the front (start) segment
  final frontLength = (visibleLength + 1) ~/ 2; // ceiling(visibleLength / 2)
  final backLength = visibleLength ~/ 2;         // floor(visibleLength / 2)

  // Extract front and back parts
  final front = input.substring(0, frontLength);
  final back = input.substring(input.length - backLength);
      
  return '$front$ellipsis$back';
}