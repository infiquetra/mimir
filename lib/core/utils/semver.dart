/// Compares two semantic version strings numerically.
///
/// Returns a negative integer if `a < b`, zero if `a == b`, and a positive integer if `a > b`.
///
/// Each string is expected to be in the form `MAJOR.MINOR.PATCH` (e.g., '1.2.3').
/// Extra components (e.g., '1.2.3.4') are ignored. Short versions (e.g., '1.2')
/// are padded with zeros (e.g., '1.2.0').
///
/// Throws a [FormatException] if either input is empty, purely whitespace,
/// or contains a non-numeric component.
int compareSemVer(String a, String b) {
  final aParts = _parseVersion(a);
  final bParts = _parseVersion(b);

  for (var i = 0; i < 3; i++) {
    final comparison = aParts[i].compareTo(bParts[i]);
    if (comparison != 0) {
      return comparison;
    }
  }

  return 0;
}

List<int> _parseVersion(String version) {
  if (version.trim().isEmpty) {
    throw FormatException('Invalid version string: "$version"', version);
  }

  final parts = version.split('.');
  final result = <int>[0, 0, 0];

  for (var i = 0; i < 3; i++) {
    if (i < parts.length) {
      final part = parts[i];
      final parsed = int.tryParse(part);

      if (parsed == null) {
        throw FormatException('Invalid non-numeric component in version: "$version"', version);
      }
      result[i] = parsed;
    }
  }

  return result;
}
