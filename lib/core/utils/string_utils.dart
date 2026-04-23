/// Utility functions for string manipulation.
/// Provides helpers for common string operations that are not
/// available in the Dart core library.

library string_utils;

import 'package:characters/characters.dart';

/// Truncates a string in the middle, replacing the removed portion
/// with an ellipsis.
///
/// If [input] is shorter than or equal to [maxLength], it is returned
/// unchanged. Otherwise, the middle of the string is replaced with
/// [ellipsis], preserving the start and end portions.
///
/// The length of the returned string (including the ellipsis) will
/// be less than or equal to [maxLength].
///
/// Examples:
///   truncateMiddle('hello', 10) → 'hello'
///   truncateMiddle('abcdefghijklmn', 8) → 'abc…lmn'
///   truncateMiddle('', 5) → ''
///   truncateMiddle('abcdef', 3) → 'a…f'  // Design choice: favor visible ends
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // Guard: negative maxLength is invalid, fail loudly
  if (maxLength <= 0) {
    throw ArgumentError.value(maxLength, 'maxLength', 'must be positive');
  }

  // Return unchanged if input is already short enough
  if (input.characters.length <= maxLength) {
    return input;
  }

  // Handle edge case where ellipsis is longer than maxLength
  if (ellipsis.characters.length > maxLength) {
    return ellipsis.characters.take(maxLength).toString();
  }

  // Calculate how many characters we can show from start and end
  final visibleBudget = maxLength - ellipsis.characters.length;

  // If we can't show any visible characters, just return the ellipsis
  if (visibleBudget <= 0) {
    return ellipsis.characters.take(maxLength).toString();
  }

  // Split visible budget consistently: prefer start when odd
  final startCount = (visibleBudget + 1) ~/ 2;
  final endCount = visibleBudget ~/ 2;

  // Construct result: start + ellipsis + end
  return input.characters.take(startCount).toString() +
      ellipsis +
      input.characters.skip(input.characters.length - endCount).toString();
}