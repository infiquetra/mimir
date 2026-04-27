/// Compares two semantic version strings numerically.
///
/// Returns a negative integer if [a] < [b], zero if [a] == [b],
/// and a positive integer if [a] > [b].
///
/// Accepts versions of the form `MAJOR.MINOR.PATCH` (e.g., `1.2.3`).
/// A short version (e.g., `1.2`) is treated as `1.2.0`.
/// Extra trailing components (e.g., `1.2.3.4`) are ignored.
///
/// Throws [FormatException] if either input is empty, purely whitespace,
/// or contains a non-numeric component in the first three positions.
int compareSemVer(String a, String b) {
  final aComponents = _parseSemVerComponents(a);
  final bComponents = _parseSemVerComponents(b);

  for (var i = 0; i < 3; i++) {
    final cmp = aComponents[i].compareTo(bComponents[i]);
    if (cmp != 0) return cmp;
  }

  return 0;
}

/// Parses a semantic version string into [major, minor, patch] integers.
///
/// Throws [FormatException] if [version] is empty, purely whitespace,
/// or contains a non-numeric component in the first three positions.
/// The exception message includes the original [version] string verbatim.
List<int> _parseSemVerComponents(String version) {
  if (version.isEmpty || version.trim().isEmpty) {
    throw FormatException('Malformed semantic version: "$version"');
  }

  final parts = version.split('.').take(3).toList();
  final components = <int>[];

  for (final part in parts) {
    final parsed = int.tryParse(part);
    if (parsed == null) {
      throw FormatException('Malformed semantic version: "$version"');
    }
    components.add(parsed);
  }

  while (components.length < 3) {
    components.add(0);
  }

  return components;
}
