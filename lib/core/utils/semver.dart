/// Compares two semantic-version strings.
///
/// Returns a negative integer if [a] < [b], zero if [a] == [b], or a
/// positive integer if [a] > [b].
///
/// Each version is parsed into exactly three numeric components by
/// splitting on `.`. Missing components (e.g. `1.2`) are padded with
/// `0`; components beyond patch (e.g. `1.2.3.4`) are ignored.
///
/// Throws [FormatException] if either input is empty, only whitespace,
/// or contains a non-numeric component.
int compareSemVer(String a, String b) {
  final aParts = _parseSemVerComponents(a);
  final bParts = _parseSemVerComponents(b);

  for (var i = 0; i < 3; i++) {
    final cmp = aParts[i].compareTo(bParts[i]);
    if (cmp != 0) {
      return cmp;
    }
  }

  return 0;
}

/// Parses [input] into exactly three integer components.
///
/// Missing components are padded with `0`. Extra components beyond
/// the third are ignored. Throws [FormatException] for malformed input.
List<int> _parseSemVerComponents(String input) {
  if (input.isEmpty || input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final parts = input.split('.');
  final result = <int>[];

  for (var i = 0; i < 3; i++) {
    if (i < parts.length) {
      final parsed = int.tryParse(parts[i]);
      if (parsed == null) {
        throw FormatException('Malformed semantic version: $input');
      }
      result.add(parsed);
    } else {
      result.add(0);
    }
  }

  return result;
}
