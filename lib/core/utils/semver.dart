/// Compares two semantic version strings.
///
/// Returns a negative integer if [a] < [b], zero if [a] == [b],
/// and a positive integer if [a] > [b].
///
/// Throws [FormatException] if either input is malformed (empty,
/// whitespace-only, or contains a non-numeric component).
int compareSemVer(String a, String b) {
  final partsA = _parseVersion(a);
  final partsB = _parseVersion(b);

  for (var i = 0; i < 3; i++) {
    final cmp = partsA[i].compareTo(partsB[i]);
    if (cmp != 0) return cmp;
  }
  return 0;
}

/// Parses a version string into exactly three numeric components.
///
/// Throws [FormatException] if the input is empty, purely whitespace,
/// or any of the first three components is non-numeric.
/// Components beyond index 2 are ignored.
/// Missing components default to zero.
List<int> _parseVersion(String input) {
  if (input.trim().isEmpty) {
    throw FormatException('Invalid semver: "$input"');
  }

  final parts = input.split('.');
  final result = <int>[];

  for (var i = 0; i < 3; i++) {
    if (i < parts.length) {
      final parsed = int.tryParse(parts[i]);
      if (parsed == null) {
        throw FormatException('Invalid semver: "$input"');
      }
      result.add(parsed);
    } else {
      result.add(0);
    }
  }

  return result;
}
