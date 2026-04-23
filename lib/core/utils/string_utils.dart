/// Utility functions for string manipulation.
library;

/// Truncates [input] in the middle if it exceeds [maxLength].
///
/// If [input.length] is less than or equal to [maxLength], returns [input] unchanged.
/// Otherwise, replaces the middle with [ellipsis] so the result length is at most
/// [maxLength]. When [maxLength] minus the ellipsis length is odd, the extra
/// character goes to the start.
///
/// If [maxLength] is shorter than the ellipsis length, returns as much of the
/// ellipsis as fits.
String truncateMiddle(String input, int maxLength, {String ellipsis = '\u2026'}) {
  if (input.length <= maxLength) return input;
  if (maxLength <= 0) return '';

  if (maxLength <= ellipsis.length) {
    return ellipsis.substring(0, maxLength);
  }

  final visibleLength = maxLength - ellipsis.length;
  final startCount = (visibleLength + 1) ~/ 2;
  final endCount = visibleLength ~/ 2;

  final start = input.substring(0, startCount);
  final end = input.substring(input.length - endCount);

  return '$start$ellipsis$end';
}