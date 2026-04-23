library;

/// Utility functions for semantic version comparison.
///
/// Compares two semantic version strings.
///
/// Returns a comparator-style integer:
/// - Negative if [a] < [b]
/// - Zero if [a] == [b]
/// - Positive if [a] > [b]
///
/// Versions are expected in the form `MAJOR.MINOR.PATCH` (e.g., `1.2.3`).
/// Missing components default to zero (e.g., `1.2` becomes `1.2.0`).
/// Extra components beyond PATCH are ignored (e.g., `1.2.3.4` becomes `1.2.3`).
///
/// Comparison is NUMERIC, not lexicographic, so `1.10.0 > 1.2.0`.
///
/// Throws [FormatException] if the version string is empty, whitespace-only,
/// or contains non-numeric components.
int compareSemVer(String a, String b) {
  final tupleA = _parseVersion(a);
  final tupleB = _parseVersion(b);

  // Compare major, then minor, then patch
  final majorDiff = tupleA[0].compareTo(tupleB[0]);
  if (majorDiff != 0) return majorDiff;

  final minorDiff = tupleA[1].compareTo(tupleB[1]);
  if (minorDiff != 0) return minorDiff;

  final patchDiff = tupleA[2].compareTo(tupleB[2]);
  return patchDiff;
}

/// Parses a version string into a three-element numeric tuple [major, minor, patch].
/// Returns [FormatException] if the string is empty, whitespace-only, or has non-numeric components.
List<int> _parseVersion(String input) {
  // Check for empty or whitespace-only input
  if (input.isEmpty || input.trim().isEmpty) {
    throw FormatException('Version string is empty or whitespace: "$input"', input);
  }

  final components = input.trim().split('.');
  final result = <int>[];

  for (int i = 0; i < 3; i++) {
    if (i < components.length) {
      final component = components[i];
      // Check if component is empty (e.g., "1..3" or "1.2.")
      if (component.isEmpty) {
        throw FormatException('Version component is empty at position $i: "$input"', input);
      }
      // Try to parse as integer
      final value = int.tryParse(component);
      if (value == null) {
        throw FormatException('Version component "$component" is not a valid integer: "$input"', input);
      }
      result.add(value);
    } else {
      // Pad missing components with zero
      result.add(0);
    }
  }

  return result;
}
