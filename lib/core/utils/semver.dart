// Semantic version comparison utilities.

/// Compares two semantic version strings numerically.
///
/// Compares major, minor, and patch components in order. Missing components
/// are treated as zero, and any components beyond patch are ignored for
/// ordering purposes.
///
/// Returns a negative integer if [a] < [b], zero if [a] == [b], or a positive
/// integer if [a] > [b]. The sign (not magnitude) is what matters.
///
/// Throws [FormatException] if either input is malformed. Malformed inputs
/// are: empty strings, strings containing only whitespace, or strings with
/// any non-numeric version component. The exception message includes the
/// offending input string verbatim.
///
/// Examples:
/// - `compareSemVer('1.2.3', '1.2.4')` → negative
/// - `compareSemVer('1.10.0', '1.2.0')` → positive (numeric, not lexicographic)
/// - `compareSemVer('1.2', '1.2.0')` → `0` (short form pads with zero)
/// - `compareSemVer('1.2.3.4', '1.2.3')` → `0` (extra components ignored)
/// - `compareSemVer('1.2.a', '1.2.3')` → throws `FormatException`
int compareSemVer(String a, String b) {
  final aParts = _parseSemVerComponents(a);
  final bParts = _parseSemVerComponents(b);

  for (var i = 0; i < 3; i++) {
    final comparison = aParts[i].compareTo(bParts[i]);
    if (comparison != 0) return comparison;
  }

  return 0;
}

/// Parses a semantic version string into exactly three integer components.
///
/// Takes the first three components from the input, appending zeroes for
/// any missing components. Extra components beyond the third are ignored.
///
/// Throws [FormatException] with the full input string in the message if:
/// - Input is empty or whitespace-only
/// - Any version component contains non-digit characters
List<int> _parseSemVerComponents(String input) {
  if (input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final trimmed = input.trim();
  final parts = trimmed.split('.');

  for (final part in parts) {
    if (!_isNumericComponent(part)) {
      throw FormatException('Malformed semantic version: $input');
    }
  }

  final numericParts = parts.map(int.parse).toList();

  // Take first 3, pad with zeros if needed
  while (numericParts.length < 3) {
    numericParts.add(0);
  }

  return numericParts.sublist(0, 3);
}

/// Returns true if [s] is a valid numeric version component (non-empty, digits only).
bool _isNumericComponent(String s) {
  return s.isNotEmpty && RegExp(r'^\d+$').hasMatch(s);
}
