/// Compares two semantic version strings numerically.
///
/// Returns a negative integer if [a] < [b], zero if equal, positive if [a] > [b].
/// Missing minor/patch components default to zero. Components beyond patch are
/// ignored. Throws [FormatException] for malformed input (empty, whitespace-only,
/// or non-numeric components in the first three positions).
int compareSemVer(String a, String b) {
  final aParts = _parseSemVer(a);
  final bParts = _parseSemVer(b);
  for (var i = 0; i < 3; i++) {
    final cmp = aParts[i].compareTo(bParts[i]);
    if (cmp != 0) return cmp;
  }
  return 0;
}

/// Parses the first three dot-separated components of [input] as integers.
///
/// Missing components (indices 0..2) default to zero. Components beyond index 2
/// are ignored. Throws [FormatException] if [input] is empty, whitespace-only,
/// or contains non-numeric content in the first three positions.
List<int> _parseSemVer(String input) {
  if (input.trim().isEmpty) {
    throw FormatException("Malformed semantic version: '$input'", input);
  }

  final parts = input.split('.');
  final result = <int>[0, 0, 0];

  final limit = parts.length < 3 ? parts.length : 3;
  for (var i = 0; i < limit; i++) {
    final component = parts[i];
    if (!_isNumeric(component)) {
      throw FormatException(
        "Malformed semantic version '$input': component '$component' is not numeric",
        input,
      );
    }
    result[i] = int.parse(component);
  }

  return result;
}

/// Returns true if [s] is a non-empty string of digits only.
bool _isNumeric(String s) {
  if (s.isEmpty) return false;
  for (var i = 0; i < s.length; i++) {
    if (s.codeUnitAt(i) < 0x30 || s.codeUnitAt(i) > 0x39) return false;
  }
  return true;
}
