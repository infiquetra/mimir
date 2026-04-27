/// Truncates [input] by replacing the middle with [ellipsis] so the result
/// fits within [maxLength] characters.
///
/// [maxLength] includes the length of [ellipsis]. When the input already fits,
/// it is returned unchanged.
///
/// When content must be trimmed, characters are split evenly between the start
/// and end of the string: `sideLength = (maxLength - ellipsis.length) ~/ 2`.
/// If the available content length is odd, one character of capacity is left
/// unused so the result is always `<= maxLength`. For example,
/// `truncateMiddle('abcdefghijklmn', 8)` produces `'abc…lmn'` (3 + 1 + 3 = 7).
///
/// When [maxLength] is very small, the design preserves one character on each
/// side if possible: `truncateMiddle('abcdef', 3)` returns `'a…f'`.
///
/// If [ellipsis] is longer than [maxLength], the ellipsis itself is truncated
/// to [maxLength] characters.
///
/// Throws [ArgumentError] if [maxLength] is negative.
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  if (maxLength < 0) {
    throw ArgumentError.value(maxLength, 'maxLength', 'must be non-negative');
  }

  if (input.length <= maxLength) return input;

  if (maxLength == 0) return '';

  if (ellipsis.length >= maxLength) return ellipsis.substring(0, maxLength);

  final availableContentLength = maxLength - ellipsis.length;
  final sideLength = availableContentLength ~/ 2;

  final start = input.substring(0, sideLength);
  final end = input.substring(input.length - sideLength);

  return '$start$ellipsis$end';
}