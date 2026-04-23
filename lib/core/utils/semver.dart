/// Semantic version comparison utility.
///
/// Compares version strings according to semantic versioning rules,
/// ignoring build metadata and pre-release identifiers (e.g., `1.2.3-alpha`
/// is not supported). Inputs are expected to be numeric `MAJOR.MINOR.PATCH`
/// strings where missing minor/patch components default to zero, and extra
/// trailing components are ignored.
///
/// Returns a comparator-style integer:
/// - negative if `a < b`
/// - zero if `a == b`
/// - positive if `a > b`
///
/// # Examples
///
/// ```dart
/// compareSemVer('1.2.3', '1.2.3') // → 0
/// compareSemVer('1.2.3', '1.2.4') // → negative
/// compareSemVer('1.10.0', '1.2.0') // → positive (numeric comparison)
/// compareSemVer('2.0.0', '1.99.99') // → positive
/// compareSemVer('1.2', '1.2.0') // → 0 (short form pads with zero)
/// compareSemVer('1.2.3.4', '1.2.3') // → 0 (extra components ignored)
/// ```
///
/// # Validation
///
/// Throws [FormatException] if either input is malformed:
/// - empty or purely whitespace string
/// - any retained component (major, minor, patch) is not numeric
///
/// The thrown exception's message includes the offending input verbatim,
/// making it possible for callers to diagnose which argument caused the error.
int compareSemVer(String a, String b) {
  final partsA = _normalizeVersion(a);
  final partsB = _normalizeVersion(b);

  for (int i = 0; i < 3; i++) {
    final cmp = partsA[i].compareTo(partsB[i]);
    if (cmp != 0) {
      return cmp;
    }
  }

  return 0;
}

/// Normalizes a version string into exactly three integer components.
///
/// Splits on '.' and retains at most three components.
/// If fewer than three components are present, missing positions default to zero.
/// If more than three components are present, extra components are ignored.
///
/// Throws [FormatException] if:
/// - input is empty or purely whitespace after trimming,
/// - any retained component cannot be parsed as an integer.
///
/// The exception's message includes the original input string.
List<int> _normalizeVersion(String version) {
  final trimmed = version.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Invalid semver string: empty or whitespace', version);
  }

  final parts = trimmed.split('.');
  // Validate all components (including extra trailing ones) because the spec says "malformed input" includes any non-numeric component.
  for (final component in parts) {
    // Must be non-empty and consist only of decimal digits (no sign, no leading zeros restriction).
    if (component.isEmpty || !RegExp(r'^\d+$').hasMatch(component)) {
      throw FormatException(
        'Invalid semver component "$component" in "$version"',
        version,
      );
    }
  }

  final retained = parts.take(3).toList();

  final result = <int>[];
  for (int i = 0; i < 3; i++) {
    if (i < retained.length) {
      final component = retained[i];
      // Already validated as numeric above.
      final value = int.parse(component);
      result.add(value);
    } else {
      result.add(0);
    }
  }

  return result;
}