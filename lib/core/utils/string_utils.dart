/// Truncates a string in the middle, keeping the start and end visible.
///
/// If the input length is less than or equal to [maxLength], returns the input
/// unchanged. Otherwise, replaces the middle with [ellipsis].
///
/// The [maxLength] includes the length of the ellipsis. The returned string
/// length is guaranteed to be less than or equal to [maxLength].
///
/// For odd visible capacity (`maxLength - ellipsis.length`), the function uses
/// floor division for both sides, intentionally leaving one unused character of
/// capacity. This ensures consistent start/end character counts.
///
/// Throws [ArgumentError] if [maxLength] is negative.
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abc…lmn'` (7 chars total)
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 3)` → `'a…f'` (3 chars total)
/// - `truncateMiddle('abcdef', 2, ellipsis: '...')` → `'..'` (truncated ellipsis)
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  if (maxLength < 0) {
    throw ArgumentError.value(
      maxLength,
      'maxLength',
      'Must be greater than or equal to 0',
    );
  }

  if (input.length <= maxLength) {
    return input;
  }

  if (ellipsis.length >= maxLength) {
    return ellipsis.substring(0, maxLength);
  }

  final visiblePerSide = (maxLength - ellipsis.length) ~/ 2;

  return '${input.substring(0, visiblePerSide)}$ellipsis${input.substring(input.length - visiblePerSide)}';
}