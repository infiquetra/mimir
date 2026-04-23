/// Truncates the middle of a string to fit within [maxLength], adding [ellipsis].
///
/// If [input].length is less than or equal to [maxLength], the input is returned unchanged.
///
/// If truncation is required, the resulting string will consist of a prefix,
/// the [ellipsis], and a suffix, such that the total length is <= [maxLength].
///
/// The visible character budget ([maxLength] - [ellipsis].length) is split between
/// the prefix and suffix. If the budget is odd, the extra character is given to the prefix.
///
/// Design choice: If [maxLength] is 3 and [ellipsis] is '…', `truncateMiddle('abcdef', 3)`
/// returns 'a…f' (prefix 1, ellipsis 1, suffix 1), preserving both ends.
///
/// If [maxLength] is less than or equal to [ellipsis].length, the [ellipsis] is
/// returned truncated to [maxLength].
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  if (input.length <= maxLength) {
    return input;
  }

  if (maxLength <= ellipsis.length) {
    return ellipsis.substring(0, maxLength);
  }

  final int budget = maxLength - ellipsis.length;
  final int prefixLength = (budget + 1) ~/ 2;
  final int suffixLength = budget ~/ 2;

  return '${input.substring(0, prefixLength)}$ellipsis${input.substring(input.length - suffixLength)}';
}
