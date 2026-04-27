/// Truncates the middle of a string to fit within [maxLength].
///
/// If [input].length is less than or equal to [maxLength], the [input] is returned unchanged.
/// Otherwise, the string is truncated from the middle, inserting the [ellipsis].
///
/// The resulting string length will always be <= [maxLength].
///
/// Design choices:
/// - [maxLength] includes the length of the [ellipsis].
/// - If [maxLength] <= 0 and truncation is needed, returns an empty string.
/// - If [maxLength] <= [ellipsis].length and truncation is needed, returns
///   the [ellipsis] truncated to fit [maxLength].
/// - To maintain symmetry, the remaining available characters ([maxLength] - [ellipsis].length)
///   are divided equally between the start and end. Any odd leftover character is dropped,
///   ensuring the result is always <= [maxLength].
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  if (input.length <= maxLength) {
    return input;
  }

  if (maxLength <= 0) {
    return '';
  }

  if (maxLength <= ellipsis.length) {
    return ellipsis.substring(0, maxLength);
  }

  final visibleChars = maxLength - ellipsis.length;
  final sideLength = visibleChars ~/ 2;

  final start = input.substring(0, sideLength);
  final end = input.substring(input.length - sideLength);

  return '$start$ellipsis$end';
}
