/// Parses a semantic version string into [major, minor, patch] components.
///
/// Short versions (e.g. '1.2') are padded with zeros.
/// Extra components (e.g. '1.2.3.4') are truncated to 3 components.
/// Throws [FormatException] for malformed input.
List<int> _parseSemVerComponents(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final parts = trimmed.split('.');

  // Parse major (always required)
  int major;
  try {
    major = int.parse(parts[0]);
  } on FormatException {
    throw FormatException('Malformed semantic version: $input');
  }

  // Parse minor (default to 0 if missing)
  int minor = 0;
  if (parts.length > 1) {
    try {
      minor = int.parse(parts[1]);
    } on FormatException {
      throw FormatException('Malformed semantic version: $input');
    }
  }

  // Parse patch (default to 0 if missing)
  int patch = 0;
  if (parts.length > 2) {
    try {
      patch = int.parse(parts[2]);
    } on FormatException {
      throw FormatException('Malformed semantic version: $input');
    }
  }

  return [major, minor, patch];
}

/// Compares two semantic version strings.
///
/// Returns a negative integer if [a] < [b], zero if [a] == [b], or a positive
/// integer if [a] > [b]. The magnitude of the return value is not specified;
/// only the sign matters.
///
/// Versions are compared numerically by major, then minor, then patch.
/// Short versions (e.g. '1.2') are treated as '1.2.0'.
/// Extra trailing components (e.g. '1.2.3.4') are ignored.
///
/// Throws [FormatException] if either input is malformed (empty, whitespace-only,
/// or contains non-numeric components).
///
/// Example:
/// ```dart
/// compareSemVer('1.2.3', '1.2.4'); // negative
/// compareSemVer('1.10.0', '1.2.0'); // positive (numeric comparison)
/// compareSemVer('1.2', '1.2.0');     // zero (short form padding)
/// ```
int compareSemVer(String a, String b) {
  final aComponents = _parseSemVerComponents(a);
  final bComponents = _parseSemVerComponents(b);

  // Compare major
  if (aComponents[0] != bComponents[0]) {
    return aComponents[0].compareTo(bComponents[0]);
  }

  // Compare minor
  if (aComponents[1] != bComponents[1]) {
    return aComponents[1].compareTo(bComponents[1]);
  }

  // Compare patch
  if (aComponents[2] != bComponents[2]) {
    return aComponents[2].compareTo(bComponents[2]);
  }

  return 0;
}
