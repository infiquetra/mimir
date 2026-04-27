/// Compares two semantic version strings numerically.
///
/// Accepts versions of the form `MAJOR.MINOR.PATCH`. Missing components
/// are treated as zero. Components beyond patch are ignored.
/// Comparison is numeric (not lexicographic) at each level.
///
/// Returns a value whose sign indicates the ordering:
///   - negative if [a] < [b]
///   - zero if [a] == [b]
///   - positive if [a] > [b]
///
/// Throws [FormatException] if either input is empty, whitespace-only,
/// or contains a non-numeric component.
int compareSemVer(String a, String b) {
  final aComponents = _parseSemVerComponents(a);
  final bComponents = _parseSemVerComponents(b);

  for (int i = 0; i < 3; i++) {
    final cmp = aComponents[i].compareTo(bComponents[i]);
    if (cmp != 0) return cmp;
  }

  return 0;
}

/// Parses a semver string into `[major, minor, patch]`.
///
/// Missing components become 0. Components beyond patch are ignored.
/// Throws [FormatException] for empty/whitespace/non-numeric input.
List<int> _parseSemVerComponents(String version) {
  if (version.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $version');
  }

  final parts = version.split('.');
  final components = <int>[];

  for (int i = 0; i < 3; i++) {
    if (i < parts.length) {
      final value = int.tryParse(parts[i]);
      if (value == null) {
        throw FormatException('Malformed semantic version: $version');
      }
      components.add(value);
    } else {
      components.add(0);
    }
  }

  return components;
}
