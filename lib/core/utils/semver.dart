/// Utility for comparing semantic version strings.
///
/// Compares versions of the form MAJOR.MINOR.PATCH numerically.
/// Short versions (e.g., `1.2`) treat missing components as zero.
/// Extra components beyond patch (e.g., `1.2.3.4`) are ignored.
library;

/// Compares two semantic version strings and returns a comparator-style
/// integer: negative if [a] < [b], zero if [a] == [b], positive if [a] > [b].
///
/// Comparison is numeric, not lexicographic: `1.10.0 > 1.2.0`.
///
/// Throws [FormatException] if either input is empty, whitespace-only,
/// or contains a non-numeric component.
int compareSemVer(String a, String b) {
  final aParts = _parseSemVer(a);
  final bParts = _parseSemVer(b);

  for (var i = 0; i < 3; i++) {
    final cmp = aParts[i].compareTo(bParts[i]);
    if (cmp != 0) return cmp;
  }

  return 0;
}

/// Parses a semantic version string into a list of exactly three integers
/// ([major, minor, patch]).
///
/// - Missing components are padded with zero (e.g., `"1.2"` → `[1, 2, 0]`).
/// - Extra components beyond patch are ignored (e.g., `"1.2.3.4"` → `[1, 2, 3]`).
/// - Throws [FormatException] if [input] is empty, whitespace-only, or
///   contains a non-numeric component.
List<int> _parseSemVer(String input) {
  if (input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: "$input"');
  }

  final components = input.split('.');
  final parts = <int>[];

  for (final component in components) {
    final value = int.tryParse(component);
    if (value == null) {
      throw FormatException('Malformed semantic version: "$input"');
    }
    parts.add(value);
  }

  // Pad missing components with zero, truncate to major.minor.patch.
  while (parts.length < 3) {
    parts.add(0);
  }

  return parts.sublist(0, 3);
}
