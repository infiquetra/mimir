/// Compares two semantic-version strings.
///
/// Returns a negative integer if [a] < [b], zero if [a] == [b], or a
/// positive integer if [a] > [b].
int compareSemVer(String a, String b) {
  final left = _parseSemVer(a);
  final right = _parseSemVer(b);

  for (var i = 0; i < 3; i++) {
    final cmp = left[i].compareTo(right[i]);
    if (cmp != 0) return cmp;
  }

  return 0;
}

List<int> _parseSemVer(String input) {
  if (input.isEmpty || input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final parts = input.split('.').take(3).toList();
  final result = <int>[];

  for (final part in parts) {
    final parsed = int.tryParse(part);
    if (parsed == null) {
      throw FormatException('Malformed semantic version: $input');
    }
    result.add(parsed);
  }

  while (result.length < 3) {
    result.add(0);
  }

  return result;
}
