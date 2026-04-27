/// Compares two semantic-version strings [a] and [b] and returns a
/// comparator-style integer: negative if [a] < [b], zero if [a] == [b],
/// positive if [a] > [b].
///
/// Versions are of the form `MAJOR.MINOR.PATCH` or shorter forms like
/// `MAJOR.MINOR` (where the missing component defaults to zero).
/// Components beyond PATCH are ignored (e.g. `1.2.3.4` is treated as
/// `1.2.3`). All components are compared numerically, not
/// lexicographically, so `1.10.0 > 1.2.0`.
///
/// Throws [FormatException] if any of the first three components is
/// non-numeric, or if the input is empty or whitespace-only.
int compareSemVer(String a, String b) {
  final aComponents = _parseSemVerComponents(a);
  final bComponents = _parseSemVerComponents(b);

  for (int i = 0; i < 3; i++) {
    final comparison = aComponents[i].compareTo(bComponents[i]);
    if (comparison != 0) return comparison;
  }

  return 0;
}

/// Parses the first three dot-separated components of [version].
///
/// Missing components (e.g. `"1.2"` has no patch) default to zero.
/// Components beyond index 2 are ignored. Throws [FormatException] if
/// any of the first three components is non-numeric or if [version] is
/// empty or whitespace-only.
List<int> _parseSemVerComponents(String version) {
  if (version.isEmpty || version.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $version');
  }

  final parts = version.split('.');
  final components = <int>[];

  for (int i = 0; i < 3; i++) {
    if (i < parts.length) {
      final parsed = int.tryParse(parts[i]);
      if (parsed == null) {
        throw FormatException('Malformed semantic version: $version');
      }
      components.add(parsed);
    } else {
      components.add(0);
    }
  }

  return components;
}
