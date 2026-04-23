/// Utility functions for string manipulation.

/// Truncates a string to [maxLength] by replacing the middle portion with
/// [ellipsis], keeping the start and end portions visible.
///
/// The total returned length (including ellipsis) is always <= [maxLength].
///
/// - If [input] is empty or [input.length] <= [maxLength], returns [input] unchanged.
/// - If [maxLength] <= 0, returns an empty string.
/// - If [maxLength] < [ellipsis].length, returns [ellipsis] truncated to [maxLength].
/// - If fewer than 2 visible characters fit ([maxLength] - [ellipsis].length < 2),
///   returns the [ellipsis] alone.
/// - When the visible budget is odd, the extra character goes to the prefix
///   (prefixCount = ceil(visibleCount / 2), suffixCount = floor(visibleCount / 2)).
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abc…lmn'`
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 3)` → `'…'`
/// - `truncateMiddle('abcdef', 4)` → `'ab…ef'`
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // Guard: non-positive maxLength → empty string
  if (maxLength <= 0) return '';

  // Guard: input already within limit → unchanged
  if (input.length <= maxLength) return input;

  // Guard: empty ellipsis → plain truncation to maxLength
  if (ellipsis.isEmpty) {
    return input.substring(0, maxLength);
  }

  // Guard: ellipsis longer than budget → truncate ellipsis to fit
  if (maxLength < ellipsis.length) {
    return ellipsis.substring(0, maxLength);
  }

  // Compute visible character budget (excluding ellipsis)
  final visibleCount = maxLength - ellipsis.length;

  // Guard: not enough room for both start and end → ellipsis alone
  if (visibleCount < 2) {
    return ellipsis;
  }

  // Split visible budget: odd budgets favor the prefix (extra char goes to start)
  final prefixCount = (visibleCount / 2).ceil();
  final suffixCount = visibleCount ~/ 2;

  return '${input.substring(0, prefixCount)}$ellipsis${input.substring(input.length - suffixCount, input.length)}';
}
