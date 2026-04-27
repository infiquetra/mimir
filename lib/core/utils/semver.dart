/// Compares two semantic-version strings and returns a comparator-style
/// integer: negative if [a] < [b], zero if [a] == [b], positive if [a] > [b].
///
/// Only the sign of the result matters (mirrors Comparable.compareTo).
int compareSemVer(String a, String b) {
  final aParts = _parseSemVer(a);
  final bParts = _parseSemVer(b);

  for (var i = 0; i < 3; i++) {
    final diff = aParts[i].compareTo(bParts[i]);
    if (diff != 0) return diff;
  }

  return 0;
}

/// Parses a semantic version string into a list of three integers: [major, minor, patch].
///
/// - Versions with fewer than 3 components are padded with zeros (e.g., "1.2" becomes [1, 2, 0]).
/// - Versions with more than 3 components have trailing components truncated (e.g., "1.2.3.4" becomes [1, 2, 3]).
/// - Throws [FormatException] if the input is empty, whitespace-only, or contains non-numeric components.
List<int> _parseSemVer(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final components = trimmed.split('.').take(3).toList();
  final result = <int>[];

  for (final component in components) {
    final value = int.tryParse(component);
    if (value == null) {
      throw FormatException('Malformed semantic version: $input');
    }
    result.add(value);
  }

  // Pad with zeros to ensure exactly 3 components
  while (result.length < 3) {
    result.add(0);
  }

  return result;
}
