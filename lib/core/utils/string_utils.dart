/// Truncates a string from the middle when it exceeds [maxLength], replacing
/// the removed middle portion with [ellipsis].
///
/// Strings with `input.length <= maxLength` are returned unchanged.
/// Otherwise, the middle is replaced by [ellipsis].
/// [maxLength] includes the ellipsis length, so the total output length is
/// always `<= maxLength`.
///
/// For very small [maxLength], the ellipsis itself is truncated so it still
/// fits — for example, `truncateMiddle('abcdef', 1)` returns `'…'`.
///
/// Odd visible-character budgets are handled consistently by assigning the
/// extra character to the start.
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abcd…lmn'`
/// - `truncateMiddle('abcdef', 3)` → `'a…f'`
String truncateMiddle(
  String input,
  int maxLength, {
  String ellipsis = '…',
}) {
  if (input.length <= maxLength) {
    return input;
  }

  if (maxLength <= 0) {
    return '';
  }

  if (ellipsis.length >= maxLength) {
    return ellipsis.substring(0, maxLength);
  }

  final visibleLength = maxLength - ellipsis.length;
  final startLength = (visibleLength + 1) ~/ 2;
  final endLength = visibleLength ~/ 2;

  return input.substring(0, startLength) +
      ellipsis +
      input.substring(input.length - endLength);
}
