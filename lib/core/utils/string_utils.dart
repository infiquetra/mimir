/// Truncates a string by replacing its middle with an ellipsis while preserving
/// the start and end.
///
/// [maxLength] includes the length of the [ellipsis]. If [input.length] is
/// less than or equal to [maxLength], [input] is returned unchanged.
///
/// When the visible budget after removing the ellipsis is odd, the extra
/// character is discarded so that equal prefix and suffix lengths are shown:
///
/// ```dart
/// truncateMiddle('abcdefghijklmn', 8) // 'abc…lmn' (3 + 1 + 3 = 7 ≤ 8)
/// truncateMiddle('abcdef', 3)           // 'a…f'     (1 + 1 + 1 = 3 ≤ 3)
/// truncateMiddle('hello', 10)           // 'hello'
/// truncateMiddle('', 5)                 // ''
/// truncateMiddle('abcdef', 1)           // '…'
/// truncateMiddle('abcdef', 0)           // ''
/// ```
///
/// If [maxLength] is shorter than [ellipsis.length], the ellipsis itself is
/// truncated to fit within [maxLength].
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
  final sideLength = visibleLength ~/ 2;
  final start = input.substring(0, sideLength);
  final end = input.substring(input.length - sideLength);

  return '$start$ellipsis$end';
}
