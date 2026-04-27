// Utility functions for comparing semantic version strings.
//
// Functions in this file support comparator-style comparison of
// [semver](https://semver.org/) strings with relaxed parsing
// (no prerelease/suffix support, missing components default to zero,
// extra trailing components are ignored).

/// Compares two semantic version strings [a] and [b] and returns:
///
/// - a negative integer if `a < b`,
/// - zero if `a == b`,
/// - a positive integer if `a > b`.
///
/// Comparison is numeric (not lexicographic), so `1.10.0 > 1.2.0`.
///
/// Missing components default to zero (e.g., `1.2` is treated as `1.2.0`).
/// Extra trailing components beyond patch are ignored (e.g., `1.2.3.4`
/// is treated as `1.2.3`).
///
/// Throws a [FormatException] if either input is empty, whitespace-only,
/// or contains a non-numeric component.
int compareSemVer(String a, String b) {
  final aParts = _parseSemVer(a);
  final bParts = _parseSemVer(b);

  for (int i = 0; i < 3; i++) {
    final cmp = aParts[i].compareTo(bParts[i]);
    if (cmp != 0) return cmp;
  }

  return 0;
}

/// Parses a semantic version string into a 3-element list of integers
/// (`[major, minor, patch]`).
///
/// Missing components default to `0`. Extra components beyond patch are
/// silently ignored. Throws [FormatException] for empty, whitespace-only,
/// or non-numeric input.
List<int> _parseSemVer(String input) {
  if (input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final parts = input.split('.');
  final result = <int>[0, 0, 0];

  for (int i = 0; i < 3 && i < parts.length; i++) {
    final value = int.tryParse(parts[i]);
    if (value == null) {
      throw FormatException('Malformed semantic version: $input');
    }
    result[i] = value;
  }

  return result;
}
