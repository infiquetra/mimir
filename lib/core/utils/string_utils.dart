/// Truncates a string in the middle, replacing the center with an ellipsis.
///
/// When the input is longer than maxLength, this function keeps the start
/// and end visible while replacing the middle with an ellipsis character.
///
/// For odd visible budgets (maxLength - ellipsis.length), the implementation
/// uses a balanced floor split: both sides get floor(visibleLength / 2)
/// characters, leaving one character unused when the budget is odd.
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'` (unchanged)
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abc…lmn'` (3+1+3=7 ≤ 8)
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 2, ellipsis: '...')` → `'..'`
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // Fast path: input fits within maxLength
  if (input.length <= maxLength) {
    return input;
  }

  // Handle maxLength too small to fit any visible characters
  final ellipsisLength = ellipsis.length;
  if (maxLength <= ellipsisLength) {
    return ellipsis.substring(0, maxLength.clamp(0, ellipsisLength));
  }

  // Normal truncation: compute visible budget
  final visibleLength = maxLength - ellipsisLength;
  final sideLength = visibleLength ~/ 2;

  final start = input.substring(0, sideLength);
  final end = input.substring(input.length - sideLength);

  return '$start$ellipsis$end';
}