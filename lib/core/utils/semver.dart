/// Parses a semantic version string into numeric components.
///
/// Accepts versions of the form "MAJOR.MINOR.PATCH" and handles:
/// - Short forms: "1.2" is treated as "1.2.0"
/// - Extra components: "1.2.3.4" is treated as "1.2.3"
///
/// Throws [FormatException] if the input is empty, whitespace-only,
/// or contains non-numeric components.
({int major, int minor, int patch}) _parseSemVer(String version) {
  final trimmed = version.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Empty or whitespace-only version string: "$version"');
  }

  final parts = trimmed.split('.');
  if (parts.isEmpty || parts.length > 3 && parts.take(3).any((p) => p.isEmpty)) {
    throw FormatException('Invalid version format: "$version"');
  }

  int parseComponent(String component, String originalVersion) {
    if (component.isEmpty) {
      return 0;
    }
    final parsed = int.tryParse(component);
    if (parsed == null) {
      throw FormatException(
        'Non-numeric version component in "$originalVersion"',
      );
    }
    return parsed;
  }

  final major = parseComponent(parts[0], version);
  final minor = parts.length > 1 ? parseComponent(parts[1], version) : 0;
  final patch = parts.length > 2 ? parseComponent(parts[2], version) : 0;

  return (major: major, minor: minor, patch: patch);
}

/// Compares two semantic version strings.
///
/// Returns a comparator-style integer:
/// - negative if [a] < [b]
/// - zero if [a] == [b]
/// - positive if [a] > [b]
///
/// Versions are compared numerically by major, minor, then patch.
/// Short forms (e.g., "1.2") are padded with zeros.
/// Extra components (e.g., "1.2.3.4") are truncated.
///
/// Throws [FormatException] if either input is empty, whitespace-only,
/// or contains non-numeric components. The exception message includes
/// the offending input string.
int compareSemVer(String a, String b) {
  final versionA = _parseSemVer(a);
  final versionB = _parseSemVer(b);

  final majorComparison = versionA.major.compareTo(versionB.major);
  if (majorComparison != 0) return majorComparison;

  final minorComparison = versionA.minor.compareTo(versionB.minor);
  if (minorComparison != 0) return minorComparison;

  return versionA.patch.compareTo(versionB.patch);
}
