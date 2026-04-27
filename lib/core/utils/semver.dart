/// Compares two semantic version strings and returns a comparator-style integer.
///
/// Returns negative if [a] < [b], zero if [a] == [b], positive if [a] > [b].
///
/// Versions are compared numerically (not lexicographically), so
/// `1.10.0 > 1.2.0`. Missing components default to zero (e.g. `1.2` is
/// treated as `1.2.0`). Extra trailing components beyond patch are ignored
/// (e.g. `1.2.3.4` is treated as `1.2.3`).
///
/// Throws [FormatException] if either version is empty, whitespace-only, or
/// contains non-numeric components.
int compareSemVer(String a, String b) {
  final aParts = _parseSemVer(a);
  final bParts = _parseSemVer(b);

  for (int i = 0; i < 3; i++) {
    final cmp = aParts[i].compareTo(bParts[i]);
    if (cmp != 0) return cmp;
  }
  return 0;
}

/// Parses a semver string into a list of three integers: [major, minor, patch].
///
/// Normalizes short versions by padding missing components with zero.
/// Ignores components beyond the third (patch). Throws [FormatException] on
/// malformed input.
List<int> _parseSemVer(String version) {
  if (version.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $version');
  }

  final parts = version.split('.');
  final result = <int>[];

  for (int i = 0; i < 3; i++) {
    if (i < parts.length) {
      final parsed = int.tryParse(parts[i]);
      if (parsed == null) {
        throw FormatException('Malformed semantic version: $version');
      }
      result.add(parsed);
    } else {
      result.add(0);
    }
  }

  return result;
}
