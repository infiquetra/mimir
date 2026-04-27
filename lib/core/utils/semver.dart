/// Compares two semantic version strings numerically.
///
/// Returns a negative integer if [a] < [b], zero if equal, a positive
/// integer if [a] > [b]. Missing components default to `0` (e.g. `1.2`
/// is treated as `1.2.0`). Components beyond the patch field are ignored.
///
/// Throws [FormatException] if either input is empty, whitespace-only, or
/// contains non-numeric components. The exception message includes the
/// offending input verbatim.
int compareSemVer(String a, String b) {
  final aParts = _parseSemVer(a);
  final bParts = _parseSemVer(b);

  for (int i = 0; i < 3; i++) {
    final cmp = aParts[i].compareTo(bParts[i]);
    if (cmp != 0) return cmp;
  }

  return 0;
}

List<int> _parseSemVer(String input) {
  if (input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final parts = input.split('.');
  final result = <int>[];

  for (int i = 0; i < 3; i++) {
    final component = i < parts.length ? parts[i] : '0';
    final value = int.tryParse(component);
    if (value == null) {
      throw FormatException('Malformed semantic version: $input');
    }
    result.add(value);
  }

  return result;
}
