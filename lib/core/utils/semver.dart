List<int> _parseSemVer(String version) {
  if (version.isEmpty || version.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $version');
  }

  final parts = version.split('.');
  final result = <int>[];

  const maxComponents = 3;
  final componentsToParse =
      parts.length < maxComponents ? parts.length : maxComponents;

  for (var i = 0; i < componentsToParse; i++) {
    final component = parts[i].trim();
    final value = int.tryParse(component);
    if (value == null) {
      throw FormatException('Malformed semantic version: $version');
    }
    result.add(value);
  }

  while (result.length < maxComponents) {
    result.add(0);
  }

  return result;
}

int compareSemVer(String a, String b) {
  final aParts = _parseSemVer(a);
  final bParts = _parseSemVer(b);

  for (var i = 0; i < 3; i++) {
    final comparison = aParts[i].compareTo(bParts[i]);
    if (comparison != 0) {
      return comparison;
    }
  }

  return 0;
}
