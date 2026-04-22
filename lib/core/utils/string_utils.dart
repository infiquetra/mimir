/// Truncates the middle of a string with an ellipsis when input exceeds [maxLength].
///
/// Maintains front-heavy visibility (more characters from start than end) with 
/// split calculated as (visibleLength + 1) ~/ 2 for front and visibleLength ~/ 2 for back.
/// When [maxLength] is less than [ellipsis] length, returns truncated ellipsis.
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