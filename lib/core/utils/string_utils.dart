/// Truncates the middle of a string to fit within [maxLength],
/// inserting [ellipsis] in the center.
///
/// If [input].length <= [maxLength], the string is returned unchanged.
/// If [maxLength] is shorter than the [ellipsis] length, the [ellipsis]
/// is returned truncated to [maxLength].
///
/// When distributing the remaining length budget between the start and end,
/// the extra character (if budget is odd) is given to the start.
/// For example, `truncateMiddle('abcdef', 3)` with `ellipsis = '…'`
/// has a budget of 3 - 1 = 2. This is split as 1 start and 1 end: 'a…f'.
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  if (input.length <= maxLength) {
    return input;
  }

  if (maxLength <= 0) {
    if (maxLength == 0) {
      return '';
    }
    throw RangeError.range(maxLength, 0, null, 'maxLength');
  }

  final int ellipsisLength = ellipsis.length;

  if (maxLength < ellipsisLength) {
    return ellipsis.substring(0, maxLength);
  }

  final int visibleCharacterBudget = maxLength - ellipsisLength;
  final int startLength = (visibleCharacterBudget + 1) ~/ 2;
  final int endLength = visibleCharacterBudget ~/ 2;

  final String prefix = startLength == 0 ? '' : input.substring(0, startLength);
  final String suffix = endLength == 0 ? '' : input.substring(input.length - endLength);

  return '$prefix$ellipsis$suffix';
}
