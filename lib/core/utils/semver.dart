int compareSemVer(String a, String b) {
  List<int> parse(String version) {
    if (version.trim().isEmpty) {
      throw FormatException('Invalid semantic version: $version');
    }

    final parts = version.split('.');
    final result = <int>[];

    for (int i = 0; i < 3; i++) {
      if (i < parts.length) {
        final part = parts[i];
        final parsed = int.tryParse(part);
        if (parsed == null) {
          throw FormatException('Invalid semantic version: $version');
        }
        result.add(parsed);
      } else {
        result.add(0);
      }
    }
    return result;
  }

  final v1 = parse(a);
  final v2 = parse(b);

  for (int i = 0; i < 3; i++) {
    final diff = v1[i].compareTo(v2[i]);
    if (diff != 0) return diff;
  }

  return 0;
}
