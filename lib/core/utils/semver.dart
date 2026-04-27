/// Compares two semantic version strings numerically.
///
/// Returns a negative integer if [a] < [b], zero if [a] == [b],
/// and a positive integer if [a] > [b].
///
/// Versions are of the form `MAJOR.MINOR.PATCH`. Missing components
/// default to zero; extra trailing components are ignored.
///
/// Throws [FormatException] for non-numeric components, empty strings,
/// or whitespace-only strings, with the offending input in the message.
int compareSemVer(String a, String b) {
  final aComponents = _parseSemVerComponents(a);
  final bComponents = _parseSemVerComponents(b);

  for (var i = 0; i < 3; i++) {
    final cmp = aComponents[i].compareTo(bComponents[i]);
    if (cmp != 0) return cmp;
  }

  return 0;
}

/// Parses the major, minor, and patch components of [version] as integers.
///
/// Throws [FormatException] if [version] is empty, whitespace-only, or
/// contains non-numeric components in the first three positions.
List<int> _parseSemVerComponents(String version) {
  if (version.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $version');
  }

  final parts = version.split('.');
  final components = <int>[];

  for (var i = 0; i < 3; i++) {
    if (i < parts.length) {
      final component = parts[i];
      final value = int.tryParse(component);
      if (value == null) {
        throw FormatException('Malformed semantic version: $version');
      }
      components.add(value);
    } else {
      components.add(0);
    }
  }

  return components;
}
