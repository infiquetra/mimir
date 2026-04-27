/// Compares two semantic version strings and returns a comparator-style integer.
///
/// Returns a negative value when [a] < [b], zero when [a] == [b], and a
/// positive value when [a] > [b].
///
/// Versions are compared numerically component by component (major → minor →
/// patch), so `1.10.0` is greater than `1.2.0`.
///
/// Short versions (e.g. `1.2`) are treated as if the missing components are
/// zero (`1.2.0`). Extra trailing components beyond patch (e.g. `1.2.3.4`)
/// are ignored.
///
/// Throws [FormatException] if [a] or [b] is empty, whitespace-only, or
/// contains a non-numeric component in the first three positions.
int compareSemVer(String a, String b) {
  final aParts = _parseSemVer(a);
  final bParts = _parseSemVer(b);

  for (int i = 0; i < 3; i++) {
    final cmp = aParts[i].compareTo(bParts[i]);
    if (cmp != 0) return cmp;
  }

  return 0;
}

/// Parses a semantic version string into a list of three integers.
///
/// Missing components are padded with zero. Components beyond the first three
/// are ignored. Throws [FormatException] for empty, whitespace-only, or
/// non-numeric input.
List<int> _parseSemVer(String input) {
  if (input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final parts = input.split('.');
  final result = <int>[];

  for (int i = 0; i < 3; i++) {
    if (i >= parts.length) {
      result.add(0);
    } else {
      final parsed = int.tryParse(parts[i]);
      if (parsed == null) {
        throw FormatException('Malformed semantic version: $input');
      }
      result.add(parsed);
    }
  }

  return result;
}
