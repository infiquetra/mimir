/// Compares two semantic version strings.
///
/// Returns a negative integer if [a] is less than [b], zero if they are equal,
/// and a positive integer if [a] is greater than [b].
///
/// Supports short-form versions (e.g., "1.2" is treated as "1.2.0") and ignores
/// trailing components beyond major.minor.patch.
///
/// Throws [FormatException] if either input is malformed (empty, whitespace-only,
/// or contains non-numeric or negative components).
int compareSemVer(String a, String b) {
  final parsedA = _parseSemVer(a);
  final parsedB = _parseSemVer(b);

  // Compare major version
  final majorComparison = parsedA.major.compareTo(parsedB.major);
  if (majorComparison != 0) return majorComparison;

  // Compare minor version
  final minorComparison = parsedA.minor.compareTo(parsedB.minor);
  if (minorComparison != 0) return minorComparison;

  // Compare patch version
  return parsedA.patch.compareTo(parsedB.patch);
}

class _SemVer {
  final int major;
  final int minor;
  final int patch;

  _SemVer(this.major, this.minor, this.patch);
}

_SemVer _parseSemVer(String version) {
  if (version.trim().isEmpty) {
    throw FormatException('Invalid semantic version: $version', version);
  }

  final parts = version.split('.');
  if (parts.isEmpty) {
    throw FormatException('Invalid semantic version: $version', version);
  }

  final major = _parseInt(parts[0], version);
  final minor = parts.length > 1 ? _parseInt(parts[1], version) : 0;
  final patch = parts.length > 2 ? _parseInt(parts[2], version) : 0;

  return _SemVer(major, minor, patch);
}

int _parseInt(String str, String originalVersion) {
  final trimmed = str.trim();
  if (trimmed.isEmpty) {
    throw FormatException(
        'Invalid semantic version component in: $originalVersion',
        originalVersion);
  }

  final parsed = int.tryParse(trimmed);
  if (parsed == null) {
    throw FormatException(
        'Invalid semantic version component in: $originalVersion',
        originalVersion);
  }

  if (parsed < 0) {
    throw FormatException(
        'Negative version component in: $originalVersion', originalVersion);
  }

  return parsed;
}
