/// Utility functions for string manipulation.

/// Truncates a string in the middle with an ellipsis.
///
/// If the [input] length is less than or equal to [maxLength], returns
/// [input] unchanged. Otherwise, replaces the middle of the string with
/// [ellipsis], keeping both the start and end portions visible.
///
/// The total length of the returned string will be at most [maxLength],
/// including the length of the ellipsis.
///
/// If [maxLength] is less than the [ellipsis] length, the ellipsis itself
/// is truncated to [maxLength] and returned alone.
///
/// When the available space for visible characters (after subtracting the
/// ellipsis length) is odd, the extra character is **dropped** so that both
/// prefix and suffix have equal length. This yields a total length less than
/// maxLength in those cases, which matches the example given in the issue.
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abc…lmn'`
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 3)` → `'a…f'`
/// - `truncateMiddle('xyz', 2)` → `'…'` (ellipsis truncated to 1 char)
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // If input already fits, return unchanged.
  if (input.length <= maxLength) {
    return input;
  }

  // Ensure non‑negative maxLength.
  if (maxLength <= 0) {
    return '';
  }

  // Ellipsis cannot exceed maxLength.
  final effectiveEllipsis =
      ellipsis.length <= maxLength ? ellipsis : ellipsis.substring(0, maxLength);

  // If the whole budget is consumed by the ellipsis, return it alone.
  if (maxLength <= effectiveEllipsis.length) {
    return effectiveEllipsis;
  }

  // Budget for visible prefix/suffix characters.
  final visibleBudget = maxLength - effectiveEllipsis.length;
  assert(visibleBudget > 0);

  // Split visible budget equally between prefix and suffix.
  // If visibleBudget is odd, the extra character is dropped (not shown),
  // because the example in the issue uses equal prefix/suffix lengths.
  final prefixCount = visibleBudget ~/ 2;
  final suffixCount = visibleBudget ~/ 2;

  // Both counts are safe because input.length > maxLength >= effectiveEllipsis.length + visibleBudget.
  return input.substring(0, prefixCount) +
         effectiveEllipsis +
         input.substring(input.length - suffixCount);
}