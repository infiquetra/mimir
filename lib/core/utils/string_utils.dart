







/// String manipulation utilities.

/// Shortens a string by replacing the middle with an ellipsis.
///
/// If [input] length ≤ [maxLength], returns [input] unchanged.
/// Otherwise, replaces characters in the middle with [ellipsis],
/// keeping as many characters from the start and end as possible,
/// such that the resulting string length ≤ [maxLength].
///
/// The [ellipsis] length counts against [maxLength]; if [maxLength]
/// is shorter than [ellipsis].length, only the first [maxLength]
/// characters of [ellipsis] are used.
///
/// When [maxLength] - [ellipsis].length is odd, the leftover
/// character is given to the start side.
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abcd…lmn'`
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 3)` → `'a…f'`
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // If input fits within maxLength, return unchanged.
  if (input.length <= maxLength) return input;

  // If maxLength is non-positive, nothing can be shown.
  if (maxLength <= 0) return '';

  // If maxLength is shorter than ellipsis, use only the first maxLength chars.
  final effectiveEllipsis = ellipsis.length > maxLength
      ? ellipsis.substring(0, maxLength)
      : ellipsis;

  // If the ellipsis alone fills the entire maxLength, there's no room for input.
  if (effectiveEllipsis.length == maxLength) return effectiveEllipsis;

  final remaining = maxLength - effectiveEllipsis.length;

  // Split visible characters between start and end, giving the extra
  // character to the start when remaining is odd.
  final leadingLength = (remaining + 1) ~/ 2;
  final trailingLength = remaining ~/ 2;

  final start = input.substring(0, leadingLength);
  final end = input.substring(input.length - trailingLength);

  return start + effectiveEllipsis + end;
}
