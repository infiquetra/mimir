/// Utility functions for semantic version comparison.
///
/// Compares two semantic version strings.
///
/// Returns a comparator-style integer:
/// - Negative if [a] < [b]
/// - Zero if [a] == [b]
/// - Positive if [a] > [b]
///
/// Components are compared numerically, not lexicographically.
/// Short versions (e.g., `1.2`) are padded with zeros (becomes `1.2.0`).
/// Extra components beyond patch (e.g., `1.2.3.4`) are ignored.
///
/// Throws [FormatException] if either version string is malformed
/// (non-numeric component, empty string, or whitespace-only).
int compareSemVer(String a, String b) {
  final aParts = _parseSemVerComponents(a);
  final bParts = _parseSemVerComponents(b);

  for (int i = 0; i < 3; i++) {
    final result = aParts[i].compareTo(bParts[i]);
    if (result != 0) return result;
  }
  return 0;
}

/// Parses a semantic version string into its numeric components.
///
/// Splits the input on '.' and converts the first three components to integers.
/// Short versions are padded with zeros to exactly three components.
///
/// Throws [FormatException] if any component is non-numeric, empty, or if
/// the entire input is empty/whitespace-only. The exception message includes
/// the original input string verbatim.
List<int> _parseSemVerComponents(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final parts = input.split('.').take(3).toList();
  final integers = <int>[];
  for (final component in parts) {
    final parsed = int.tryParse(component);
    if (parsed == null) {
      throw FormatException('Malformed semantic version: $input');
    }
    integers.add(parsed);
  }

  // Pad with zeros to exactly three components
  while (integers.length < 3) {
    integers.add(0);
  }

  return integers;
}
