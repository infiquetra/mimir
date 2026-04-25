/// Compares two semantic-version strings numerically.
///
/// Returns a negative integer if [a] < [b], zero if [a] == [b],
/// or a positive integer if [a] > [b] — mirroring [Comparable.compareTo].
///
/// Short versions are padded with zeros (e.g. `"1.2"` → `1.2.0`).
/// Components beyond patch are ignored (e.g. `"1.2.3.4"` → `1.2.3`).
///
/// Throws [FormatException] if either input is malformed (empty,
/// whitespace-only, contains non-numeric or empty components).
/// The exception message includes the offending input verbatim.
int compareSemVer(String a, String b) {
  final aParts = _parseSemVer(a);
  final bParts = _parseSemVer(b);
  for (var i = 0; i < 3; i++) {
    final cmp = aParts[i].compareTo(bParts[i]);
    if (cmp != 0) return cmp;
  }
  return 0;
}

/// Parses a semantic-version string into exactly three integer components.
///
/// Validates every component in the original input (not just the first three).
/// Pads missing minor/patch with 0; truncates components beyond patch only
/// after validation succeeds.
///
/// Throws [FormatException] with the original input included verbatim
/// in the message if validation fails.
List<int> _parseSemVer(String version) {
  if (version.isEmpty || version.trim().isEmpty) {
    throw FormatException('Invalid semantic version: "$version"');
  }
  final parts = version.split('.');
  // Validate every component — empty segments or non-numeric are malformed.
  for (final part in parts) {
    if (part.isEmpty || int.tryParse(part) == null) {
      throw FormatException('Invalid semantic version: "$version"');
    }
  }
  return [
    int.parse(parts[0]),
    parts.length > 1 ? int.parse(parts[1]) : 0,
    parts.length > 2 ? int.parse(parts[2]) : 0,
  ];
}