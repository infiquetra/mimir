/// Compares two semantic version strings.
///
/// Returns a negative integer if [a] is less than [b],
/// zero if [a] is equal to [b],
/// and a positive integer if [a] is greater than [b].
///
/// Versions are compared numerically by major, minor, and patch components.
/// Short versions (e.g., '1.2') are padded with zeros ('1.2.0').
/// Extra trailing components (e.g., '1.2.3.4') are truncated to just patch.
///
/// Throws [FormatException] if either input is empty, whitespace-only,
/// or contains non-numeric components.
///
/// Examples:
/// - `compareSemVer('1.2.3', '1.2.3')` → `0`
/// - `compareSemVer('1.2.3', '1.2.4')` → negative
/// - `compareSemVer('1.10.0', '1.2.0')` → positive (numeric, not lexicographic)
/// - `compareSemVer('1.2', '1.2.0')` → `0` (short form pads with zero)
/// - `compareSemVer('1.2.3.4', '1.2.3')` → `0` (extra components ignored)
int compareSemVer(String a, String b) {
  final aComponents = _parseVersion(a);
  final bComponents = _parseVersion(b);

  for (var i = 0; i < 3; i++) {
    final comparison = aComponents[i].compareTo(bComponents[i]);
    if (comparison != 0) return comparison;
  }

  return 0;
}

/// Parses a version string into [major, minor, patch] integers.
///
/// - Version must be non-empty after trimming.
/// - Components must be numeric (no pre-release or build metadata).
/// - Missing minor/patch are treated as 0.
/// - Extra components beyond patch are ignored.
List<int> _parseVersion(String version) {
  final trimmed = version.trim();

  if (trimmed.isEmpty) {
    throw FormatException('Invalid semantic version: "$version"');
  }

  final parts = trimmed.split('.').take(3).toList();

  if (parts.isEmpty) {
    throw FormatException('Invalid semantic version: "$version"');
  }

  final components = <int>[];
  for (final part in parts) {
    final trimmedPart = part.trim();
    final parsed = int.tryParse(trimmedPart);
    if (parsed == null) {
      throw FormatException('Invalid semantic version: "$version"');
    }
    components.add(parsed);
  }

  // Pad missing minor/patch with zeros
  while (components.length < 3) {
    components.add(0);
  }

  return components;
}
