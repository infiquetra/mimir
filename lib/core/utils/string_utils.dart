/// Utility functions for string manipulation.

/// Truncates a long string by replacing the middle with an ellipsis.
///
/// Keeps the beginning and end of the string visible, replacing the middle
/// with the specified ellipsis string. The total length of the result
/// will never exceed [maxLength].
///
/// If [input.length] is already <= [maxLength], returns [input] unchanged.
///
/// If [maxLength] is shorter than [ellipsis.length], the ellipsis itself
/// is truncated to fit within [maxLength].
///
/// When the available space for visible characters (after accounting for
/// the ellipsis) is odd, the leftover character is intentionally left
/// unused to maintain balanced start/end visibility. For example:
/// `truncateMiddle('abcdefghijklmn', 8)` → `'abc…lmn'` (3 + 1 + 3 = 7 chars,
/// leaving one character of the 8-character budget unused).
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abc…lmn'`
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 0)` → `''`
/// - `truncateMiddle('abcdef', 1)` → `'…'`
///
/// Throws [ArgumentError] if [maxLength] is negative.
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  if (maxLength < 0) {
    throw ArgumentError.value(maxLength, 'maxLength', 'must be non-negative');
  }

  // Already within limit - return unchanged
  if (input.length <= maxLength) {
    return input;
  }

  // Not enough room for even the ellipsis - truncate ellipsis itself
  if (maxLength <= ellipsis.length) {
    return ellipsis.substring(0, maxLength);
  }

  // Calculate available space for visible characters
  final available = maxLength - ellipsis.length;
  // Use floor division to keep start/end balanced; odd leftover is intentionally unused
  final sideLength = available ~/ 2;

  final start = input.substring(0, sideLength);
  final end = input.substring(input.length - sideLength);

  return '$start$ellipsis$end';
}
