/// Compares two semantic-version strings numerically.
///
/// Returns a comparator-style integer: negative if [a] < [b], zero if
/// [a] == [b], positive if [a] > [b].
///
/// Short versions (e.g. `"1.2"`) are treated as `"1.2.0"` — missing
/// components default to zero. Extra trailing components (e.g.
/// `"1.2.3.4"`) beyond patch are ignored.
///
/// Throws [FormatException] if either input is empty, whitespace-only,
/// or contains a non-numeric component in the first three positions.
int compareSemVer(String a, String b) {
  final partsA = _parseSemVerComponents(a);
  final partsB = _parseSemVerComponents(b);

  for (int i = 0; i < 3; i++) {
    final cmp = partsA[i].compareTo(partsB[i]);
    if (cmp != 0) return cmp;
  }

  return 0;
}

/// Parses a version string into exactly three integer components.
///
/// Missing components are padded with zero. Input must not be empty,
/// whitespace-only, or contain non-numeric components in the first
/// three positions.
List<int> _parseSemVerComponents(String input) {
  if (input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final components = input.split('.');

  final result = <int>[];
  final limit = components.length < 3 ? components.length : 3;

  for (int i = 0; i < limit; i++) {
    final value = int.tryParse(components[i]);
    if (value == null) {
      throw FormatException('Malformed semantic version: $input');
    }
    result.add(value);
  }

  // Pad with zeros until we have exactly 3 components.
  while (result.length < 3) {
    result.add(0);
  }

  return result;
}
