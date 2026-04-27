/// Utility functions for semantic version comparison.

/// Compares two semantic version strings and returns:
/// - a negative integer if `a < b`,
/// - zero if `a == b`,
/// - a positive integer if `a > b`.
///
/// Versions are parsed as `MAJOR.MINOR.PATCH`. Missing components default to
/// zero, and components beyond patch are ignored. Comparison is numeric, not
/// lexicographic, so `1.10.0 > 1.2.0`.
///
/// Throws [FormatException] if either input is empty, whitespace-only, or
/// contains a non-numeric component.
int compareSemVer(String a, String b) {
  final aParts = _parseSemVer(a);
  final bParts = _parseSemVer(b);

  for (int i = 0; i < 3; i++) {
    if (aParts[i] != bParts[i]) {
      return aParts[i].compareTo(bParts[i]);
    }
  }

  return 0;
}

List<int> _parseSemVer(String input) {
  if (input.isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }
  if (input.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $input');
  }

  final parts = input.split('.');
  final result = <int>[];

  for (final component in parts.take(3)) {
    final value = int.tryParse(component);
    if (value == null) {
      throw FormatException('Malformed semantic version: $input');
    }
    result.add(value);
  }

  while (result.length < 3) {
    result.add(0);
  }

  return result;
}
