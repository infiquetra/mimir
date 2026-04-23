/// Semver utilities.
library;

/// Compares two semantic-version strings and returns a comparator-style integer:
/// negative if [a] < [b], zero if [a] == [b], positive if [a] > [b].
///
/// Accepts versions of the form MAJOR.MINOR.PATCH (e.g. 1.2.3) and compares
/// major -> minor -> patch numerically.
///
/// - Short versions (e.g. 1.2) are treated as 1.2.0.
/// - Extra components (e.g. 1.2.3.4) are ignored.
/// - Malformed input (non-numeric, empty, or whitespace) throws FormatException.
/// - The FormatException message includes the offending input string verbatim.
int compareSemVer(String a, String b) {
  final versionA = _parseSemVer(a);
  final versionB = _parseSemVer(b);

  for (var i = 0; i < 3; i++) {
    final cmp = versionA[i].compareTo(versionB[i]);
    if (cmp != 0) return cmp;
  }

  return 0;
}

List<int> _parseSemVer(String version) {
  if (version.trim().isEmpty) {
    throw FormatException('Invalid semver: "$version" is empty or whitespace');
  }

  final parts = version.split('.');
  final result = <int>[];

  for (var i = 0; i < 3; i++) {
    if (i < parts.length) {
      final part = parts[i];
      final value = int.tryParse(part);
      if (value == null) {
        throw FormatException('Invalid semver: "$version" has non-numeric component "$part"');
      }
      result.add(value);
    } else {
      result.add(0);
    }
  }

  return result;
}
