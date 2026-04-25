// Utility functions for semantic versioning.

/// Compares two semantic-version strings and returns a comparator-style integer.
///
/// Returns a negative integer if `a < b`, zero if `a == b`, and a positive
/// integer if `a > b`.
///
/// Accepts versions of the form `MAJOR.MINOR.PATCH` (e.g., `1.2.3`) and compares
/// components numerically. Missing components default to zero (e.g., `1.2` is
/// treated as `1.2.0`). Components beyond patch (e.g., `1.2.3.4`) are ignored.
///
/// Throws a [FormatException] if either input is empty, purely whitespace, or
/// contains a non-numeric component that impacts the comparison. The exception
/// message will contain the offending input string.
int compareSemVer(String a, String b) {
  final versionA = _parseSemVer(a);
  final versionB = _parseSemVer(b);

  for (var i = 0; i < 3; i++) {
    final cmp = versionA[i].compareTo(versionB[i]);
    if (cmp != 0) return cmp;
  }

  return 0;
}

/// Parses a version string into its [major, minor, patch] components.
List<int> _parseSemVer(String input) {
  if (input.trim().isEmpty) {
    throw FormatException('Version string cannot be empty or whitespace: "$input"');
  }

  final components = input.split('.');
  final result = <int>[0, 0, 0];

  for (var i = 0; i < 3 && i < components.length; i++) {
    final component = components[i];
    final value = int.tryParse(component);

    if (value == null) {
      throw FormatException('Invalid numeric component "$component" in version string: "$input"');
    }

    result[i] = value;
  }

  return result;
}
