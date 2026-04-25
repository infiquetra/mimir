/// Utility functions for string manipulation.

/// Truncates [input] to [maxLength] by replacing the middle with [ellipsis],
/// keeping the start and end visible.
///
/// The odd-budget rule: when `(maxLength - ellipsis.length)` is odd, the
/// extra character is given to the start portion.
///
/// - Returns [input] unchanged if `input.length <= maxLength`.
/// - Returns `ellipsis.substring(0, maxLength)` if `maxLength <= ellipsis.length`.
/// - Throws [ArgumentError] if [maxLength] is negative.
/// - Returns `''` if [maxLength] is zero.
String truncateMiddle(
  String input,
  int maxLength, {
  String ellipsis = '…',
}) {
  if (maxLength < 0) {
    throw ArgumentError('maxLength must not be negative', 'maxLength');
  }
  if (maxLength == 0) {
    return '';
  }
  if (input.length <= maxLength) {
    return input;
  }
  if (maxLength <= ellipsis.length) {
    return ellipsis.substring(0, maxLength);
  }

  final visibleCount = maxLength - ellipsis.length;
  // Odd budget goes to the start: (n+1)/2 for start, n/2 for end
  final startCount = (visibleCount + 1) ~/ 2;
  final endCount = visibleCount ~/ 2;

  return '${input.substring(0, startCount)}$ellipsis${input.substring(input.length - endCount)}';
}
