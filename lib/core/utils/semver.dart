/// Compares two semantic-version strings.
///
/// Returns a negative integer if [a] < [b], zero if [a] == [b],
/// and a positive integer if [a] > [b].
///
/// Supports `MAJOR.MINOR.PATCH` format with numeric comparison.
/// Missing components are treated as zero (e.g., `1.2` == `1.2.0`).
/// Components beyond patch are ignored (e.g., `1.2.3.4` == `1.2.3`).
///
/// Throws [FormatException] for malformed input (empty, whitespace-only,
/// or non-numeric components).
int compareSemVer(String a, String b) {
  final aComponents = _parseSemVerComponents(a);
  final bComponents = _parseSemVerComponents(b);

  for (int i = 0; i < 3; i++) {
    final comparison = aComponents[i].compareTo(bComponents[i]);
    if (comparison != 0) return comparison;
  }

  return 0;
}

/// Parses a version string into a list of three integer components.
///
/// Returns `[major, minor, patch]`. Missing components default to 0.
/// Extra components (index 3+) are ignored.
///
/// Throws [FormatException] if the input is empty, whitespace-only, or
/// contains a non-numeric component.
List<int> _parseSemVerComponents(String input) {
  if (input.trim().isEmpty) {
    throw FormatException(
      'Malformed semantic version: "$input"',
      input,
    );
  }

  final parts = input.split('.');
  final components = <int>[0, 0, 0];

  for (int i = 0; i < 3 && i < parts.length; i++) {
    final component = parts[i];
    if (!RegExp(r'^\d+$').hasMatch(component)) {
      throw FormatException(
        'Malformed semantic version: "$input"',
        input,
      );
    }
    components[i] = int.parse(component);
  }

  return components;
}
