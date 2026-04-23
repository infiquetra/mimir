import 'package:characters/characters.dart';

/// Utility functions for string manipulation.

/// Truncates [input] in the middle if it exceeds [maxLength].
///
/// If the string length is less than or equal to [maxLength], the original string is returned.
/// Otherwise, the middle part is replaced with [ellipsis] such that the
/// resulting string length is at most [maxLength].
///
/// Implementation is grapheme-aware and will not split emojis or combined characters.
String truncateMiddle(String input, int maxLength, {String ellipsis = '\u2026'}) {
  final inputChars = input.characters;
  if (inputChars.length <= maxLength) return input;
  if (maxLength <= 0) return '';

  final ellipsisChars = ellipsis.characters;
  if (maxLength <= ellipsisChars.length) {
    return ellipsisChars.take(maxLength).toString();
  }

  final visibleChars = maxLength - ellipsisChars.length;
  final startCount = (visibleChars + 1) ~/ 2;
  final endCount = visibleChars ~/ 2;

  final start = inputChars.take(startCount).toString();
  final end = inputChars.takeLast(endCount).toString();

  return '$start$ellipsis$end';
}
