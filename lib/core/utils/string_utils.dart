/// Truncates a string from the middle, replacing the middle section with an ellipsis.
///
/// If the input length is less than or equal to [maxLength], returns [input] unchanged.
/// Otherwise, keeps the start and end of the string visible and inserts [ellipsis] in the middle.
///
/// The total length of the result (including ellipsis) will be <= [maxLength].
///
/// For small [maxLength] values where even the ellipsis doesn't fit completely,
/// returns a truncated version of the ellipsis alone.
///
/// Design choice for [maxLength] == 3: returns one visible character on each side
/// of the ellipsis (e.g., 'a…f') because one character can be kept on each side
/// while still satisfying length <= maxLength.
///
/// Throws [ArgumentError] if [maxLength] is negative.
String truncateMiddle(
  String input,
  int maxLength, {
  String ellipsis = '…',
}) {
  if (maxLength < 0) {
    throw ArgumentError.value(
      maxLength,
      'maxLength',
      'Must be greater than or equal to 0',
    );
  }

  // Guard: return unchanged if already fits
  if (input.length <= maxLength) {
    return input;
  }

  // Calculate visible length budget after ellipsis
  final int visibleLength = maxLength - ellipsis.length;

  // Too-small budget: return truncated ellipsis alone
  if (visibleLength < 0) {
    return ellipsis.substring(0, maxLength);
  }

  // Distribute visible characters: extra goes to start when odd
  final int startLength = (visibleLength / 2).ceil();
  final int endLength = visibleLength ~/ 2;

  return '${input.substring(0, startLength)}$ellipsis${input.substring(input.length - endLength)}';
}
