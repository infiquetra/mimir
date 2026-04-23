import 'dart:core';

/// Compares two semantic version strings numerically.
/// 
/// Returns:
/// - A negative integer if [a] < [b]
/// - Zero if [a] == [b]
/// - A positive integer if [a] > [b]
/// 
/// Throws [FormatException] if either input is malformed (empty, whitespace-only,
/// or contains non-numeric components in the first three segments).
int compareSemVer(String a, String b) {
  final List<int> versionA = _parseVersion(a);
  final List<int> versionB = _parseVersion(b);

  for (int i = 0; i < 3; i++) {
    final int diff = versionA[i].compareTo(versionB[i]);
    if (diff != 0) {
      return diff;
    }
  }

  return 0;
}

List<int> _parseVersion(String input) {
  if (input.trim().isEmpty) {
    throw FormatException('Malformed version string: "$input"');
  }

  final parts = input.split('.');
  final List<int> components = [];

  for (int i = 0; i < 3; i++) {
    if (i < parts.length) {
      final part = parts[i];
      if (part.isEmpty) {
        throw FormatException('Malformed version string: "$input"');
      }
      final parsed = int.tryParse(part);
      if (parsed == null) {
        throw FormatException('Malformed version string: "$input"');
      }
      components.add(parsed);
    } else {
      components.add(0);
    }
  }

  return components;
}
