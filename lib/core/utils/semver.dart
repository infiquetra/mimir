// Semantic version comparison utility.

/// Compares two semantic version strings and returns a comparator-style integer.
///
/// Parses versions of the form MAJOR.MINOR.PATCH and compares them numerically.
/// - Returns negative if [a] < [b], zero if [a] == [b], positive if [a] > [b].
/// - Short versions like "1.2" are treated as "1.2.0" (missing components default to 0).
/// - Extra components like "1.2.3.4" are truncated to "1.2.3" (components beyond patch are ignored).
/// - Non-numeric components, empty strings, or whitespace-only strings throw [FormatException].
///
/// Throws [FormatException] with message containing the offending input string if parsing fails.
int compareSemVer(String a, String b) {
  final versionA = _parseVersion(a);
  final versionB = _parseVersion(b);

  final majorCompare = versionA.major.compareTo(versionB.major);
  if (majorCompare != 0) return majorCompare;

  final minorCompare = versionA.minor.compareTo(versionB.minor);
  if (minorCompare != 0) return minorCompare;

  return versionA.patch.compareTo(versionB.patch);
}

/// Holds the parsed version components.
class _Version {
  final int major;
  final int minor;
  final int patch;

  const _Version(this.major, this.minor, this.patch);
}

/// Parses a version string into major, minor, patch components.
///
/// - Splits on '.' and takes only the first three components.
/// - Missing components default to 0.
/// - Extra components are ignored.
/// - Throws [FormatException] if the input is empty/whitespace or any consumed component is non-numeric.
_Version _parseVersion(String version) {
  if (version.trim().isEmpty) {
    throw FormatException('Invalid version: "$version"');
  }

  final parts = version.split('.');
  final components = <int>[];

  // Parse only the first 3 components (major, minor, patch)
  for (var i = 0; i < 3; i++) {
    final part = i < parts.length ? parts[i] : '0';
    final parsed = int.tryParse(part);
    if (parsed == null) {
      throw FormatException('Invalid version: "$version"');
    }
    components.add(parsed);
  }

  return _Version(components[0], components[1], components[2]);
}
