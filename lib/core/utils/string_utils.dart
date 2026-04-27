/// Utility functions for string manipulation.

/// Truncates a string to [maxLength] by replacing the middle with [ellipsis],
/// keeping the start and end portions visible.
///
/// When the input already fits within [maxLength], it is returned unchanged.
/// When [maxLength] is smaller than or equal to the ellipsis length, the
/// ellipsis (or its prefix) is returned.
///
/// Design choice: `truncateMiddle('abcdef', 3)` returns `'a…f'` — one visible
/// character is kept on each side when the remaining visible budget is 2
/// (i.e., `maxLength - ellipsis.length`).
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abcd…lmn'`
/// - `truncateMiddle('abcdef', 3)` → `'a…f'`
/// - `truncateMiddle('', 5)` → `''`
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  if (maxLength < 0) {
    throw ArgumentError.value(
      maxLength,
      'maxLength',
      'must be non-negative',
    );
  }

  // Input already fits — return unchanged (covers empty string case)
  if (input.length <= maxLength) {
    return input;
  }

  // Ellipsis consumes all (or more than) the available space
  if (ellipsis.length >= maxLength) {
    return ellipsis.substring(0, maxLength);
  }

  // Budget for visible characters after reserving room for ellipsis
  final visibleLength = maxLength - ellipsis.length;
  final startLength = (visibleLength + 1) ~/ 2;
  final endLength = visibleLength ~/ 2;

  final start = input.substring(0, startLength);
  final end = input.substring(input.length - endLength);

  return '$start$ellipsis$end';
}
