/// Compares two semantic version strings.
///
/// Compares two semantic-version strings and returns a comparator-style
/// integer: negative if `a < b`, zero if `a == b`, positive if `a > b`.
///
/// Versions are expected to be in the form `MAJOR.MINOR.PATCH`.
/// Missing components default to zero, and extra components beyond
/// patch are ignored. Comparison is numeric, not lexicographic.
///
/// Throws [FormatException] if either input is empty, whitespace-only,
/// or contains non-numeric components in the first three positions.
int compareSemVer(String a, String b) {
  final versionA = _parseVersion(a, a);
  final versionB = _parseVersion(b, b);

  for (var i = 0; i < 3; i++) {
    final diff = versionA[i] - versionB[i];
    if (diff != 0) return diff;
  }

  return 0;
}

/// Parses a version string into a list of three integers [major, minor, patch].
/// 
/// Missing components default to 0, extra components are ignored.
/// The original input string is included in error messages on failure.
List<int> _parseVersion(String version, String originalInput) {
  final trimmed = version.trim();

  if (trimmed.isEmpty) {
    throw FormatException(
      'Invalid semantic version: "$originalInput" — input cannot be empty or whitespace',
    );
  }

  final parts = trimmed.split('.');
  final result = <int>[];

  // Process only the first 3 components
  for (var i = 0; i < 3; i++) {
    if (i < parts.length) {
      final part = parts[i];
      if (part.isEmpty) {
        throw FormatException(
          'Invalid semantic version: "$originalInput" — empty component at position $i',
        );
      }
      final value = int.tryParse(part);
      if (value == null) {
        throw FormatException(
          'Invalid semantic version: "$originalInput" — non-numeric component "$part"',
        );
      }
      result.add(value);
    } else {
      // Missing component defaults to 0
      result.add(0);
    }
  }

  return result;
}
