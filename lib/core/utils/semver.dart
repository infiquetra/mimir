/// Utility functions for semantic version comparison.
///
/// Follows SemVer 2.0.0 specification for format but only implements
/// basic numeric component comparison (MAJOR.MINOR.PATCH).
library;

/// Compares two semantic version strings.
///
/// Compares versions numerically (not lexicographically) in MAJOR.MINOR.PATCH order.
/// Short versions are padded with zeros (e.g. '1.2' becomes '1.2.0').
/// Extra components beyond PATCH are ignored (e.g. '1.2.3.4' becomes '1.2.3').
///
/// Returns:
/// * negative integer if [a] < [b]
/// * zero if [a] == [b]
/// * positive integer if [a] > [b]
///
/// Throws [FormatException] if either input is malformed (non-numeric components,
/// empty string, or purely whitespace).
int compareSemVer(String a, String b) {
  final aParts = _parseSemVerComponents(a);
  final bParts = _parseSemVerComponents(b);

  // Compare each component in order
  for (int i = 0; i < 3; i++) {
    final result = aParts[i].compareTo(bParts[i]);
    if (result != 0) {
      return result;
    }
  }

  // All components equal
  return 0;
}

/// Parses a semantic version string into exactly 3 numeric components.
///
/// Takes the first three dot-separated components, ignoring extras.
/// Pads with zeros if fewer than three components.
/// Throws [FormatException] for non-numeric components, empty strings, or whitespace.
List<int> _parseSemVerComponents(String input) {
  // Check for empty or whitespace-only input
  if (input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  // Split on dots and take first three components
  final parts = input.split('.').take(3).toList();

  // Parse each component to int
  final components = <int>[];
  for (final part in parts) {
    final parsed = int.tryParse(part);
    if (parsed == null) {
      throw FormatException('Malformed semantic version: $input');
    }
    components.add(parsed);
  }

  // Pad with zeros if needed
  while (components.length < 3) {
    components.add(0);
  }

  return components;
}
