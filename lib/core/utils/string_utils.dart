/// Utility functions for working with strings.

/// Truncates a string by replacing its middle with an ellipsis if it exceeds [maxLength].
///
/// Returns the original [input] unchanged if its length is already within [maxLength].
/// Otherwise, replaces the middle portion with [ellipsis], keeping balanced start and
/// end portions visible. The resulting string length is always <= [maxLength].
///
/// Design choices:
/// - When `maxLength - ellipsis.length` is odd, the extra visible character is discarded
///   to maintain balanced start/end segments (using integer division for both sides).
/// - When `maxLength == 3` with default ellipsis, returns `'a…f'` style (one char each side)
///   since the default ellipsis is a single character.
/// - When [maxLength] is shorter than [ellipsis], returns a truncated version of ellipsis alone.
/// - Negative [maxLength] values throw [ArgumentError] as no valid string can satisfy the constraint.
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'` (unchanged, within limit)
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abc…lmn'` (3 + 1 ellipsis + 3 = 7 chars)
/// - `truncateMiddle('', 5)` → `''` (empty string unchanged)
/// - `truncateMiddle('abcdef', 3)` → `'a…f'` (one char each side)
/// - `truncateMiddle('abcdef', 1)` → `'…'` (truncated ellipsis)
/// - `truncateMiddle('abcdef', 2, ellipsis: '...')` → `'..'` (ellipsis truncated to fit)
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  if (maxLength < 0) {
    throw ArgumentError.value(maxLength, 'maxLength', 'must be non-negative');
  }

  // If input fits within maxLength, return unchanged
  if (input.length <= maxLength) {
    return input;
  }

  final ellipsisLength = ellipsis.length;

  // If maxLength is too small for even the ellipsis, return truncated ellipsis
  if (maxLength <= ellipsisLength) {
    return ellipsis.substring(0, maxLength);
  }

  // At this point: input.length > maxLength and maxLength > ellipsisLength
  final visibleChars = maxLength - ellipsisLength;
  final sideLength = visibleChars ~/ 2;

  final start = input.substring(0, sideLength);
  final end = input.substring(input.length - sideLength);

  return '$start$ellipsis$end';
}
