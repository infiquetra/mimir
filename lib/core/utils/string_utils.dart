/// Utility functions for string manipulation.
///
/// Contains helpers for transforming and formatting strings in various ways.
library string_utils;

/// Truncates a string in the middle with an ellipsis.
///
/// If [input]'s length is less than or equal to [maxLength], returns [input] unchanged.
/// Otherwise replaces the middle portion with [ellipsis], keeping start and end portions visible.
///
/// The computation ensures the result length is always `<= maxLength`:
/// - If [maxLength] <= 0, returns empty string
/// - If [maxLength] <= [ellipsis].length, returns a substring of [ellipsis] with length [maxLength]
/// - Otherwise computes prefix and suffix lengths to distribute visible characters around the ellipsis
///
/// When [maxLength] - [ellipsis].length is odd, the extra visible character is given to the prefix.
///
/// Examples:
/// - `truncateMiddle('hello', 10)` → `'hello'`
/// - `truncateMiddle('abcdefghijklmn', 8)` → `'abcd…lmn'` (3 prefix + 1 ellipsis + 3 suffix = 7 chars)
/// - `truncateMiddle('', 5)` → `''`
/// - `truncateMiddle('abcdef', 3)` → `'a…f'` (1 prefix + 1 ellipsis + 1 suffix = 3 chars)
///
/// Parameters:
/// - [input]: The string to potentially truncate
/// - [maxLength]: Maximum allowed length including the ellipsis
/// - [ellipsis]: String to insert in place of removed middle content (defaults to '…')
String truncateMiddle(String input, int maxLength, {String ellipsis = '…'}) {
  // Early return if input is already short enough
  if (input.length <= maxLength) {
    return input;
  }

  // Handle edge cases where maxLength is very small
  if (maxLength <= 0) {
    return '';
  }

  if (maxLength <= ellipsis.length) {
    return ellipsis.substring(0, maxLength);
  }

  // Calculate how many characters we can show excluding the ellipsis
  final visibleCharacters = maxLength - ellipsis.length;
  
  // Distribute visible characters between prefix and suffix
  // When visibleCharacters is odd, give the extra character to the prefix
  final prefixLength = visibleCharacters ~/ 2;
  final suffixLength = visibleCharacters ~/ 2;
  
  // If we have an odd number of visible characters, give one more to prefix
  final extraChar = visibleCharacters % 2;
  final adjustedPrefixLength = prefixLength + extraChar;

  return input.substring(0, adjustedPrefixLength) + 
         ellipsis + 
         input.substring(input.length - suffixLength);
}