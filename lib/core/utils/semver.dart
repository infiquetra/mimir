/// Semantic version comparison utilities.
library;

/// Compares two semantic version strings.
///
/// Returns a negative integer if [a] < [b], zero if [a] == [b],
/// and a positive integer if [a] > [b], following [Comparable.compareTo] semantics.
///
/// Malformed input throws [FormatException] with the offending string preserved
/// in the exception message.
int compareSemVer(String a, String b) {
  final aComponents = _parseSemVerComponents(a);
  final bComponents = _parseSemVerComponents(b);

  for (var i = 0; i < 3; i++) {
    final cmp = aComponents[i].compareTo(bComponents[i]);
    if (cmp != 0) return cmp;
  }
  return 0;
}

List<int> _parseSemVerComponents(String input) {
  if (input.isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }
  if (input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final parts = input.split('.');
  final ints = <int>[];

  for (final part in parts) {
    final parsed = int.tryParse(part);
    if (parsed == null) {
      throw FormatException('Malformed semantic version: $input');
    }
    ints.add(parsed);
  }

  // Truncate: ignore components beyond patch (index >= 3).
  final truncated = ints.take(3).toList();

  // Pad: append zeroes until length is exactly 3.
  while (truncated.length < 3) {
    truncated.add(0);
  }

  return truncated;
}
