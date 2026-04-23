import 'dart:core';

/// Compares two semantic version strings.
///
/// Returns a negative value if [a] < [b], zero if [a] == [b], and a positive value if [a] > [b].
///
/// Supports versions in the form MAJOR.MINOR.PATCH.
/// - Short versions (e.g., '1.2') are padded with zeros (e.g., '1.2.0').
/// - Extra components beyond the patch (e.g., '1.2.3.4') are ignored.
/// - Throws [FormatException] if the input is malformed (empty, whitespace, or non-numeric components).
int compareSemVer(String a, String b) {
  final partsA = _parseVersion(a);
  final partsB = _parseVersion(b);

  for (int i = 0; i < 3; i++) {
    final diff = partsA[i].compareTo(partsB[i]);
    if (diff != 0) return diff;
  }

  return 0;
}

List<int> _parseVersion(String version) {
  if (version.trim().isEmpty) {
    throw FormatException('Malformed version string: "$version"');
  }

  final segments = version.split('.');
  final parsed = <int>[];

  for (int i = 0; i < 3; i++) {
    if (i < segments.length) {
      final segment = segments[i];
      if (segment.isEmpty) {
        throw FormatException('Malformed version string: "$version"');
      }
      final val = int.tryParse(segment);
      if (val == null) {
        throw FormatException('Malformed version string: "$version"');
      }
      parsed.add(val);
    } else {
      parsed.add(0);
    }
  }

  return parsed;
}
