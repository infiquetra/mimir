/// Semantic version comparison utilities.
library;

/// Compares two semantic version strings.
///
/// Returns a comparator-style integer:
/// - Negative if [a] < [b]
/// - Zero if [a] == [b]
/// - Positive if [a] > [b]
///
/// Examples:
/// - `compareSemVer('1.2.3', '1.2.3')` → `0`
/// - `compareSemVer('1.2.3', '1.2.4')` → negative
/// - `compareSemVer('1.10.0', '1.2.0')` → positive (numeric, not lexicographic)
/// - `compareSemVer('2.0.0', '1.99.99')` → positive
/// - `compareSemVer('1.2', '1.2.0')` → `0` (short form pads with zero)
/// - `compareSemVer('1.2.3.4', '1.2.3')` → `0` (extra components ignored)
///
/// Throws [FormatException] if either version string is malformed:
/// - Empty or whitespace-only
/// - Contains non-numeric components
int compareSemVer(String a, String b) {
  final aComponents = _parseVersion(a);
  final bComponents = _parseVersion(b);

  for (int i = 0; i < 3; i++) {
    final diff = aComponents[i] - bComponents[i];
    if (diff != 0) {
      return diff;
    }
  }
  return 0;
}

/// Parses a version string into its numeric components.
///
/// Returns a list of exactly 3 integers [major, minor, patch].
/// Throws [FormatException] if the input is malformed.
List<int> _parseVersion(String version) {
  if (version.isEmpty || version.trim().isEmpty) {
    throw FormatException('Invalid version: "$version"', version, 0);
  }

  final parts = version.split('.');
  if (parts.length < 3) {
    // Pad with zeros
    while (parts.length < 3) {
      parts.add('0');
    }
  } else if (parts.length > 3) {
    // Truncate to first 3 components
    parts.removeRange(3, parts.length);
  }

  final components = <int>[];
  for (int i = 0; i < 3; i++) {
    final part = parts[i];
    final parsed = int.tryParse(part);
    if (parsed == null) {
      throw FormatException('Invalid version: "$version"', version, 0);
    }
    components.add(parsed);
  }

  return components;
}
