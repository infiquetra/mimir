/// Truncates the middle of a string with an ellipsis, keeping start and end visible.
///
/// Uses a front-heavy split policy for odd-length visible segments.
/// If [maxLength] is too small for the ellipsis, returns a truncated ellipsis.
/// 
/// Examples:
/// - truncateMiddle('hello', 10) → 'hello'
/// - truncateMiddle('abcdefghijklmn', 8) → 'abcd…lmn'
/// - truncateMiddle('', 5) → ''
/// - truncateMiddle('abcdef', 3) → 'a…f'
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // Validate inputs
  if (maxLength < 0) {
    throw ArgumentError.value(maxLength, 'maxLength', 'Must be non-negative');
  }
  
  // If input is short enough, return unchanged
  if (input.length <= maxLength) {
    return input;
  }

  // Calculate visible length (excluding ellipsis)
  final visibleLength = maxLength - ellipsis.length;

  // If maxLength is too small for even the ellipsis, return truncated ellipsis
  if (visibleLength <= 0) {
    return ellipsis.substring(0, maxLength < ellipsis.length ? maxLength : ellipsis.length);
  }

  // Split visible characters between front and back with front-heavy policy
  final frontLength = (visibleLength + 1) ~/ 2;
  final backLength = visibleLength ~/ 2;

  // Build result string
  final front = input.substring(0, frontLength);
  final back = backLength > 0 ? input.substring(input.length - backLength) : '';

  return '$front$ellipsis$back';
}