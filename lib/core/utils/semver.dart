/// Parses a semver string into its [major, minor, patch] integer components.
///
/// Throws [FormatException] if the input is empty, purely whitespace, or
/// contains a non-numeric component in the first three positions.
/// Components beyond patch (index > 2) are ignored.
List<int> _parseSemVerCore(String input) {
  if (input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final parts = input.split('.');
  final result = <int>[];
  for (var i = 0; i < 3; i++) {
    if (i < parts.length) {
      final value = int.tryParse(parts[i]);
      if (value == null) {
        throw FormatException('Malformed semantic version: $input');
      }
      result.add(value);
    } else {
      result.add(0);
    }
  }
  return result;
}

/// Compares two semantic-version strings numerically.
///
/// Returns a negative integer if [a] < [b], zero if [a] == [b],
/// and a positive integer if [a] > [b].
///
/// Missing components (e.g. "1.2" for "1.2.0") default to zero.
/// Extra components beyond patch are ignored (e.g. "1.2.3.4" == "1.2.3").
///
/// Throws [FormatException] if either input is empty, purely whitespace,
/// or contains a non-numeric major/minor/patch component.
int compareSemVer(String a, String b) {
  final aParts = _parseSemVerCore(a);
  final bParts = _parseSemVerCore(b);

  for (var i = 0; i < 3; i++) {
    final cmp = aParts[i].compareTo(bParts[i]);
    if (cmp != 0) return cmp;
  }
  return 0;
}
