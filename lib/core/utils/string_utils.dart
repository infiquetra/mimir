/// String utility functions.
library;

/// Truncates a string by replacing the middle with an ellipsis.
///
/// If [input]'s length is less than or equal to [maxLength], returns
/// [input] unchanged.
///
/// Otherwise, replaces the middle of the string with [ellipsis],
/// keeping characters from the start and end such that the total length
/// does not exceed [maxLength].
///
/// The function guarantees that:
/// - The returned length is ≤ [maxLength].
/// - If [maxLength] ≤ 0, an empty string is returned.
/// - If [ellipsis.length] ≥ [maxLength], [ellipsis] is truncated to
///   [maxLength] characters and returned.
/// - When [maxLength] – [ellipsis.length] is odd, the extra character
///   is left unused, preserving symmetry.
///
/// ## Examples
///
/// ```dart
/// truncateMiddle('hello', 10);               // 'hello'
/// truncateMiddle('abcdefghijklmn', 8);      // 'abc…lmn'
/// truncateMiddle('', 5);                     // ''
/// truncateMiddle('abcdef', 2, ellipsis: '---'); // '--'
/// truncateMiddle('abcdef', 3);               // 'a…f'
/// ```
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  if (input.length <= maxLength) {
    return input;
  }
  if (maxLength <= 0) {
    return '';
  }
  if (ellipsis.length >= maxLength) {
    return ellipsis.substring(0, maxLength);
  }

  final available = maxLength - ellipsis.length;
  final sideLength = available ~/ 2; // floor division

  final start = input.substring(0, sideLength);
  final end = input.substring(input.length - sideLength);
  return '$start$ellipsis$end';
}
