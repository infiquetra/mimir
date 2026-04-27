/// Compares two semantic version strings.
///
/// Returns a negative integer if [a] < [b], zero if [a] == [b],
/// and a positive integer if [a] > [b].
///
/// Versions are compared numerically (not lexicographically) by
/// major, then minor, then patch components.
///
/// - Short versions like "1.2" are treated as "1.2.0"
/// - Extra components beyond patch (e.g., "1.2.3.4") are ignored
/// - Malformed versions throw [FormatException] with the offending input in the message
int compareSemVer(String a, String b) {
  final aParts = _parseSemVerParts(a);
  final bParts = _parseSemVerParts(b);

  for (var i = 0; i < 3; i++) {
    final comparison = aParts[i].compareTo(bParts[i]);
    if (comparison != 0) {
      return comparison;
    }
  }

  return 0;
}

/// Parses a semantic version string into major, minor, and patch components.
///
/// - Empty or whitespace-only strings throw [FormatException]
/// - Each component must be parseable as an integer
/// - Missing minor or patch components default to 0
/// - Components beyond the third are ignored
List<int> _parseSemVerParts(String version) {
  if (version.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $version');
  }

  final parts = version.split('.');
  final result = <int>[];

  for (var i = 0; i < 3; i++) {
    if (i < parts.length) {
      final parsed = int.tryParse(parts[i]);
      if (parsed == null) {
        throw FormatException('Malformed semantic version: $version');
      }
      result.add(parsed);
    } else {
      result.add(0);
    }
  }

  return result;
}
