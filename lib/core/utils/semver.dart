/// Compares two semantic-version strings numerically.
///
/// Returns:
/// - A negative integer if [a] < [b]
/// - Zero if [a] == [b]
/// - A positive integer if [a] > [b]
///
/// Throws a [FormatException] if either string is malformed.
int compareSemVer(String a, String b) {
  final aParts = _parseSemVer(a);
  final bParts = _parseSemVer(b);

  for (var i = 0; i < 3; i++) {
    final diff = aParts[i].compareTo(bParts[i]);
    if (diff != 0) {
      return diff;
    }
  }

  return 0;
}

/// Parses a version string into exactly three integer components.
List<int> _parseSemVer(String version) {
  if (version.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $version', version);
  }

  final rawParts = version.split('.');
  final List<int> parsed = [];

  for (var i = 0; i < 3 && i < rawParts.length; i++) {
    final component = rawParts[i];
    final value = int.tryParse(component);
    if (value == null) {
      throw FormatException('Malformed semantic version: $version', version);
    }
    parsed.add(value);
  }

  while (parsed.length < 3) {
    parsed.add(0);
  }

  return parsed;
}
