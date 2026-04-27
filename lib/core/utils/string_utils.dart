/// Utility functions for string manipulation.

/// Truncates a string to [maxLength] by replacing the middle with [ellipsis],
/// keeping the start and end visible.
///
/// - Returns [input] unchanged when `input.length <= maxLength`.
/// - [maxLength] includes the ellipsis; the returned string length is always `<= maxLength`.
/// - When `maxLength` is too small to display any visible characters on both sides,
///   the ellipsis is truncated to fit (or returned alone if [ellipsis] itself fits).
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abc…lmn'` (3 + 1 + 3 = 7 chars ≤ 8)
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 3)` → `'a…f'` (2 chars on each side of '…' fits within maxLength=3)
/// - `truncateMiddle('abcdef', 1)` → `'…'` (only the ellipsis fits)
/// - `truncateMiddle('abcdef', 0)` → `''`
///
/// When `maxLength - ellipsis.length` is odd, the extra character is dropped
/// to keep truncation visually balanced.
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // Return input unchanged when it already fits.
  if (input.length <= maxLength) return input;

  // Non-positive maxLength: return empty string.
  if (maxLength <= 0) return '';

  // Ellipsis itself exceeds maxLength: truncate the ellipsis.
  if (ellipsis.length >= maxLength) {
    return ellipsis.substring(0, maxLength);
  }

  // Normal case: replace the middle with ellipsis, keeping both ends.
  final available = maxLength - ellipsis.length;
  final sideLength = available ~/ 2;
  return '${input.substring(0, sideLength)}$ellipsis${input.substring(input.length - sideLength)}';
}
