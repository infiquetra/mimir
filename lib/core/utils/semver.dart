/// Compares two semantic version strings.
///
/// Returns a comparator-style integer:
/// - negative if `a < b`
/// - zero if `a == b`
/// - positive if `a > b`
///
/// Versions are of the form MAJOR.MINOR.PATCH (e.g. `1.2.3`).
/// Comparison is numeric (not lexicographic): `1.10.0 > 1.2.0`.
///
/// Missing components are padded with zero: `1.2` is treated as `1.2.0`.
///
/// Extra components beyond patch are ignored: `1.2.3.4` is treated as `1.2.3`.
///
/// Malformed input (non‑numeric component, empty string, or purely whitespace string)
/// throws a [FormatException] whose message includes the offending input string.
int compareSemVer(String a, String b) {
  final aParts = _parseSemVerComponents(a);
  final bParts = _parseSemVerComponents(b);

  for (int i = 0; i < 3; i++) {
    final comparison = aParts[i].compareTo(bParts[i]);
    if (comparison != 0) {
      return comparison;
    }
  }

  return 0;
}

/// Parses a semantic version string into [major, minor, patch].
///
/// Components are parsed as integers via [int.tryParse].
/// Throws [FormatException] if a component is non‑numeric, or if the input
/// is empty or purely whitespace.
List<int> _parseSemVerComponents(String input) {
  // Empty or whitespace‑only input is malformed.
  if (input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final parts = input.split('.');

  // Select three components, defaulting to '0' when missing.
  final majorStr = parts.isNotEmpty ? parts[0] : '0';
  final minorStr = parts.length > 1 ? parts[1] : '0';
  final patchStr = parts.length > 2 ? parts[2] : '0';

  final major = int.tryParse(majorStr);
  final minor = int.tryParse(minorStr);
  final patch = int.tryParse(patchStr);

  if (major == null || minor == null || patch == null) {
    throw FormatException('Malformed semantic version: $input');
  }

  return [major, minor, patch];
}