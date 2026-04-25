/// Utility functions for semantic version comparison.

library;

/// Compares two semantic version strings.
///
/// Returns a comparator-style integer: negative if `a < b`, zero if `a == b`,
/// positive if `a > b`.
///
/// - Accepts versions of the form `MAJOR.MINOR.PATCH` (e.g. `1.2.3`).
/// - Compares major → minor → patch NUMERICALLY (not lexicographically), so `1.10.0 > 1.2.0`.
/// - A short version (e.g. `1.2`) is treated as `1.2.0` — missing components default to zero.
/// - A single-component version (e.g. `1`) is treated as `1.0.0`.
/// - A version with extra trailing components (e.g. `1.2.3.4`) is treated as `1.2.3`.
///
/// Throws [FormatException] if either input is malformed:
/// - non-numeric component
/// - empty string
/// - purely whitespace string
///
/// Example:
/// ```dart
/// compareSemVer('1.2.3', '1.2.3'); // → 0
/// compareSemVer('1.2.3', '1.2.4'); // → negative
/// compareSemVer('1.10.0', '1.2.0'); // → positive
/// compareSemVer('2.0.0', '1.99.99'); // → positive
/// compareSemVer('1.2', '1.2.0'); // → 0 (short form pads with zero)
/// compareSemVer('1', '1.0.0'); // → 0 (single component pads with zeros)
/// compareSemVer('1.2.3.4', '1.2.3'); // → 0 (extra components ignored)
/// compareSemVer('1.2.a', '1.2.3'); // → throws FormatException
/// ```
int compareSemVer(String a, String b) {
  final aParsed = _parseSemVer(a);
  final bParsed = _parseSemVer(b);

  final majorDiff = aParsed.major.compareTo(bParsed.major);
  if (majorDiff != 0) return majorDiff;

  final minorDiff = aParsed.minor.compareTo(bParsed.minor);
  if (minorDiff != 0) return minorDiff;

  return aParsed.patch.compareTo(bParsed.patch);
}

/// Parsing result for a semantic version string.
class _SemVerParts {
  final int major;
  final int minor;
  final int patch;

  _SemVerParts(this.major, this.minor, this.patch);
}

/// Parses a semantic version string into its numeric components.
///
/// Only the first three components (major, minor, patch) are consumed.
/// Missing components default to 0. Extra components beyond patch are ignored.
///
/// Accepts versions of the form:
/// - "MAJOR" (e.g. "1") → treated as 1.0.0
/// - "MAJOR.MINOR" (e.g. "1.2") → treated as 1.2.0
/// - "MAJOR.MINOR.PATCH" (e.g. "1.2.3")
///
/// Throws [FormatException] if the input is empty, whitespace-only, or contains
/// non-numeric components.
_SemVerParts _parseSemVer(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Invalid semver: empty string: "$input"', input);
  }

  final parts = trimmed.split('.');
  if (parts.isEmpty || parts.every((p) => p.trim().isEmpty)) {
    throw FormatException('Invalid semver: empty string: "$input"', input);
  }

  // Parse components, treating missing ones as 0
  final major = parts.isNotEmpty && parts[0].trim().isNotEmpty
      ? _parseIntComponent(parts[0], 'major', input)
      : 0;

  final minor = parts.length > 1 && parts[1].trim().isNotEmpty
      ? _parseIntComponent(parts[1], 'minor', input)
      : 0;

  final patch = parts.length > 2 && parts[2].trim().isNotEmpty
      ? _parseIntComponent(parts[2], 'patch', input)
      : 0;

  return _SemVerParts(major, minor, patch);
}

/// Parses a single component as an integer.
///
/// Throws [FormatException] if the component is not a valid integer string.
int _parseIntComponent(String component, String name, String originalInput) {
  final trimmed = component.trim();
  if (trimmed.isEmpty) {
    throw FormatException(
        'Invalid semver: $name component is empty: $originalInput',
        originalInput);
  }

  // Check if the string contains only digits
  if (RegExp(r'^\d+$').hasMatch(trimmed)) {
    return int.parse(trimmed);
  }

  throw FormatException(
      'Invalid semver: $name component is not a valid integer: $originalInput',
      originalInput);
}
