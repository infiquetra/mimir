/// Utility functions for string manipulation.
///
library;

/// Truncates a string from the middle, preserving start and end.
///
/// Returns `input` unchanged if its length ≤ `maxLength`.
/// Otherwise replaces the middle portion of the string with `ellipsis`
/// (default '…') so that the resulting length is ≤ `maxLength`.
///
/// The `maxLength` parameter includes the length of the ellipsis.
/// If `maxLength` ≤ 0, returns an empty string.
/// If `maxLength` < `ellipsis.length`, the ellipsis itself is
/// truncated to fit `maxLength`.
///
/// When `maxLength - ellipsis.length` is odd, the extra character is
/// given to the start side (i.e., the left side receives one more
/// character than the right).
///
/// Example:
/// ```dart
/// truncateMiddle('hello', 10);                  // 'hello'
/// truncateMiddle('abcdefghijklmn', 8);           // 'abcd…lmn'
/// truncateMiddle('', 5);                         // ''
/// truncateMiddle('abcdef', 3);                   // 'a…f'
/// truncateMiddle('abcdef', 2, ellipsis: '...');  // '..'
/// ```
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // Fast path: input already fits.
  if (input.length <= maxLength) {
    return input;
  }

  // maxLength ≤ 0 → empty string.
  if (maxLength <= 0) {
    return '';
  }

  // If ellipsis doesn't fit, return it truncated to maxLength.
  if (maxLength <= ellipsis.length) {
    return ellipsis.substring(0, maxLength);
  }

  // Amount of visible characters besides the ellipsis.
  final visibleCharacters = maxLength - ellipsis.length;

  // Start‑biased split: give the extra character to the start when odd.
  final startLength = (visibleCharacters + 1) ~/ 2;
  final endLength = visibleCharacters ~/ 2;

  return input.substring(0, startLength) +
      ellipsis +
      input.substring(input.length - endLength);
}
