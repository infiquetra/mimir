/// Semantic version comparison utility.
///
/// Compare two semantic-version strings and return a comparator-style integer:
/// negative if `a < b`, zero if `a == b`, positive if `a > b`.
///
/// The version string format is `MAJOR.MINOR.PATCH` (e.g. `1.2.3`).
/// Components are compared NUMERICALLY, not lexicographically,
/// so `1.10.0` is greater than `1.2.0`.
///
/// Missing components default to zero (`1.2` is treated as `1.2.0`).
/// Extra trailing components after patch are ignored (`1.2.3.4` is treated as `1.2.3`).
///
/// Malformed input (non-numeric component, empty string, or purely whitespace string)
/// throws a `FormatException`. The exception message includes the offending input verbatim.
int compareSemVer(String a, String b) {
  final partsA = _parseSemVer(a);
  final partsB = _parseSemVer(b);
  for (var i = 0; i < partsA.length; i++) {
    final comparison = partsA[i].compareTo(partsB[i]);
    if (comparison != 0) {
      return comparison;
    }
  }
  return 0;
}

List<int> _parseSemVer(String input) {
  if (input.isEmpty || input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }
  final components = input.split('.');
  final result = <int>[];
  for (var i = 0; i < 3; i++) {
    if (i < components.length) {
      final component = components[i];
      if (!RegExp(r'^\d+$').hasMatch(component)) {
        throw FormatException('Malformed semantic version: $input');
      }
      result.add(int.parse(component));
    } else {
      result.add(0);
    }
  }
  return result;
}