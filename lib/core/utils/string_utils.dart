/// Utility functions for string manipulation.

/// Truncates a string to fit within a maximum length by replacing the middle
/// with an ellipsis, keeping both ends visible.
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abc…lmn'` (3 + 1 ellipsis + 3, total 7 ≤ 8)
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 3)` → `'…'` (not enough room to keep both ends)
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // If input already fits, return unchanged
  if (input.length <= maxLength) {
    return input;
  }

  // If maxLength is zero or negative, return empty string
  if (maxLength <= 0) {
    return '';
  }

  // If maxLength is shorter than ellipsis, truncate ellipsis to fit
  if (maxLength < ellipsis.length) {
    return ellipsis.substring(0, maxLength);
  }

  // Calculate how many visible characters we can keep
  final visibleCharacterBudget = maxLength - ellipsis.length;

  // If not enough room to keep both ends visible (need at least 2 chars),
  // return just the ellipsis
  if (visibleCharacterBudget < 2) {
    return ellipsis;
  }

  // Split the budget evenly, prioritizing prefix for odd budgets
  final middleBudget = visibleCharacterBudget - (visibleCharacterBudget % 2);
  final prefixLength = middleBudget ~/ 2;
  final suffixLength = middleBudget ~/ 2;

  final prefix = input.substring(0, prefixLength);
  final suffix = input.substring(input.length - suffixLength);

  return '$prefix$ellipsis$suffix';
}
