/// Utility functions for semantic version comparison.
library;

/// Compares two semantic-version strings numerically.
///
/// Returns a negative integer if [a] < [b], zero if [a] == [b],
/// or a positive integer if [a] > [b].
///
/// Components beyond patch (e.g. the `.4` in `1.2.3.4`) are ignored.
/// Missing components default to zero, so `1.2` is treated as `1.2.0`.
///
/// Throws [FormatException] if either input is malformed (empty,
/// whitespace-only, or contains a non-numeric component). The message
/// includes the offending input verbatim.
int compareSemVer(String a, String b) {
  final aComponents = _parseSemVerComponents(a);
  final bComponents = _parseSemVerComponents(b);

  for (var i = 0; i < 3; i++) {
    final result = aComponents[i].compareTo(bComponents[i]);
    if (result != 0) return result;
  }

  return 0;
}

/// Parses a semantic-version string into exactly three integer components.
///
/// Takes at most the first three dot-separated components; pads missing
/// components with zero. Throws [FormatException] for malformed input,
/// including empty/whitespace-only strings and non-numeric components.
List<int> _parseSemVerComponents(String input) {
  if (input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final parts = input.split('.');
  final components = <int>[];

  for (final part in parts.take(3)) {
    final value = int.tryParse(part);
    if (value == null) {
      throw FormatException('Malformed semantic version: $input');
    }
    components.add(value);
  }

  // Pad missing components with zero.
  while (components.length < 3) {
    components.add(0);
  }

  return components;
}
