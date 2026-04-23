/// Utility functions for semantic version comparison.
///
/// Provides a [compareSemVer] function that compares two semantic version
/// strings and returns a comparator-style integer: negative if a < b,
/// zero if a == b, positive if a > b.

library semver;

/// Compares two semantic version strings.
///
/// Accepts versions of the form MAJOR.MINOR.PATCH (e.g. "1.2.3") and compares
/// major → minor → patch NUMERICALLY (not lexicographically), so "1.10.0 > 1.2.0".
///
/// A short version (e.g. "1.2") is treated as "1.2.0" — missing components
/// default to zero.
///
/// A version with extra trailing components (e.g. "1.2.3.4") is treated as
/// "1.2.3" — components beyond patch are ignored.
///
/// Returns:
/// - Negative integer if [a] < [b]
/// - Zero if [a] == [b]
/// - Positive integer if [a] > [b]
///
/// Throws [FormatException] if either version string is malformed:
/// - Empty or whitespace-only
/// - Contains non-numeric components (e.g. "1.2.a")
/// - Contains signed components (e.g. "-1.2.3" or "+1.2.3")
int compareSemVer(String a, String b) {
  final aParts = _parseVersion(a);
  final bParts = _parseVersion(b);

  // Compare major, minor, patch in order
  final majorDiff = aParts[0].compareTo(bParts[0]);
  if (majorDiff != 0) return majorDiff;

  final minorDiff = aParts[1].compareTo(bParts[1]);
  if (minorDiff != 0) return minorDiff;

  final patchDiff = aParts[2].compareTo(bParts[2]);
  return patchDiff;
}

/// Parses a semantic version string and returns a normalized 3-element list.
///
/// Throws [FormatException] if the input is malformed (empty, whitespace-only,
/// or contains non-numeric components).
List<int> _parseVersion(String input) {
  // Reject empty or whitespace-only input
  if (input.isEmpty || input.trim().isEmpty) {
    throw FormatException(
        'Invalid version string: expected semantic version (e.g. "1.2.3"), got "$input"');
  }

  final trimmed = input.trim();
  final parts = trimmed.split('.');

  // Only inspect first three components (major, minor, patch)
  // Pad missing positions with 0
  final normalized = List<int>.filled(3, 0);

  for (int i = 0; i < 3; i++) {
    if (i >= parts.length) {
      break;
    }

    final component = parts[i];

    // Require decimal digits only - reject signed values, empty strings, etc.
    if (component.isEmpty || !RegExp(r'^\d+$').hasMatch(component)) {
      throw FormatException(
          'Invalid version string: component "$component" in "$input" is not a valid non-negative integer');
    }

    normalized[i] = int.parse(component);
  }

  return normalized;
}
