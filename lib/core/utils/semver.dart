/// Compares two semantic version strings.
///
/// Returns a comparator-style integer: negative if `a < b`, zero if `a == b`,
/// positive if `a > b`. Versions are compared numerically by major, minor,
/// then patch components.
///
/// Short versions (e.g., `1.2`) are padded with zeros to `1.2.0`.
/// Extra components beyond patch (e.g., `1.2.3.4`) are ignored.
///
/// Throws [FormatException] if either input is empty, whitespace-only,
/// or contains non-numeric components.
int compareSemVer(String a, String b) {
  final versionA = _parseVersion(a);
  final versionB = _parseVersion(b);

  for (var i = 0; i < 3; i++) {
    final comparison = versionA[i].compareTo(versionB[i]);
    if (comparison != 0) {
      return comparison;
    }
  }

  return 0;
}

/// Parses a semantic version string into a list of [major, minor, patch].
///
/// Missing components are padded with 0.
/// Extra components beyond patch are ignored.
/// Throws [FormatException] for malformed input.
List<int> _parseVersion(String version) {
  final trimmed = version.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Invalid semantic version: "$version"');
  }

  final parts = trimmed.split('.');
  if (parts.isEmpty) {
    throw FormatException('Invalid semantic version: "$version"');
  }

  // Parse up to 3 components, ignore the rest
  final result = <int>[];
  for (var i = 0; i < 3; i++) {
    if (i < parts.length) {
      final parsed = int.tryParse(parts[i]);
      if (parsed == null) {
        throw FormatException('Invalid semantic version: "$version"');
      }
      result.add(parsed);
    } else {
      // Pad missing components with 0
      result.add(0);
    }
  }

  return result;
}
