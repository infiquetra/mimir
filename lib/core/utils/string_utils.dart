library;

/// Utility functions for string operations.

/// Truncates a string in the middle, replacing the middle portion with an
/// ellipsis while keeping the start and end visible.
///
/// The ellipsis length counts toward the total [maxLength]. If the ellipsis
/// itself is longer than [maxLength], the ellipsis is truncated to fit.
///
/// Design choice: when [maxLength] is insufficient to show both leading and
/// trailing characters (visibleBudget < 2), returns the ellipsis alone,
/// potentially truncated.
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'` (unchanged, fits within maxLength)
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abcd…lmn'` (4 + 1 ellipsis + 3 = 8 chars)
/// - `truncateMiddle('', 5)` → `''` (empty string handled)
/// - `truncateMiddle('abcdef', 3)` → `'a…f'` (visibleBudget = 2, distributed: 1 start + 1 end)
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // Guard: unchanged path - if input fits within maxLength, return as-is
  if (input.length <= maxLength) {
    return input;
  }

  // Guard: empty input returns empty regardless of maxLength
  if (input.isEmpty) {
    return '';
  }

  // Guard: maxLength <= 0 means no room for content, return empty string
  if (maxLength <= 0) {
    return '';
  }

  // Compute effective ellipsis: truncate if it exceeds maxLength
  final String effectiveEllipsis;
  if (ellipsis.length <= maxLength) {
    effectiveEllipsis = ellipsis;
  } else {
    effectiveEllipsis = ellipsis.substring(0, maxLength);
  }

  // Compute visible budget for content (not ellipsis)
  final int visibleBudget = maxLength - effectiveEllipsis.length;

  // If not enough room for even one character on each side, return ellipsis alone
  if (visibleBudget < 2) {
    return effectiveEllipsis;
  }

  // Distribute visible budget: odd budget gets extra character on the front
  final int startLength = (visibleBudget + 1) ~/ 2;
  final int endLength = visibleBudget ~/ 2;

  return '${input.substring(0, startLength)}$effectiveEllipsis${input.substring(input.length - endLength)}';
}
