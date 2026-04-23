/// Compares two semantic version strings.
///
/// Returns a comparator-style integer:
/// - Negative if `a < b`
/// - Zero if `a == b`
/// - Positive if `a > b`
///
/// Accepts versions of the form `MAJOR.MINOR.PATCH` (e.g. `1.2.3`) and compares
/// major → minor → patch NUMERICALLY (not lexicographically), so `1.10.0 > 1.2.0`.
///
/// A short version (e.g. `1.2`) is treated as `1.2.0` — missing components default to zero.
///
/// A version with extra trailing components (e.g. `1.2.3.4`) is treated as `1.2.3`.
/// Components beyond patch are ignored.
///
/// Malformed input throws [FormatException]. "Malformed" means any of:
/// - Non-numeric component
/// - Empty string
/// - Purely whitespace string
///
/// The [FormatException] message includes the offending input string verbatim.
///
/// Examples:
/// - `compareSemVer('1.2.3', '1.2.3')` → `0`
/// - `compareSemVer('1.2.3', '1.2.4')` → negative
/// - `compareSemVer('1.10.0', '1.2.0')` → positive (numeric, not lexicographic)
/// - `compareSemVer('2.0.0', '1.99.99')` → positive
/// - `compareSemVer('1.2', '1.2.0')` → `0` (short form pads with zero)
/// - `compareSemVer('1.2.3.4', '1.2.3')` → `0` (extra components ignored)
/// - `compareSemVer('1.2.a', '1.2.3')` → throws [FormatException] whose message contains `'1.2.a'`
int compareSemVer(String a, String b) {
  final normalizedA = _normalizeVersion(a);
  final normalizedB = _normalizeVersion(b);

  for (int i = 0; i < 3; i++) {
    final result = normalizedA[i].compareTo(normalizedB[i]);
    if (result != 0) {
      return result;
    }
  }

  return 0;
}

/// Normalizes a version string into a list of exactly three numeric components.
///
/// Validates the input string and throws [FormatException] if it's invalid.
/// Validates that every dot-separated component is non-empty and parseable as an integer.
/// After validation, splits on `.`, takes the first three components, and pads with 0.
List<int> _normalizeVersion(String version) {
  final trimmed = version.trim();

  // Validate input is not empty or whitespace-only
  if (trimmed.isEmpty) {
    throw FormatException('Invalid semver for "$version"');
  }

  // Split into components
  final components = trimmed.split('.');

  // Validate each component is non-empty and numeric
  for (int i = 0; i < components.length; i++) {
    final component = components[i];
    if (component.isEmpty) {
      throw FormatException(
          'Invalid semver "$version": empty component at position $i');
    }
    // Try to parse as integer; if it fails, it's non-numeric
    if (int.tryParse(component) == null) {
      throw FormatException(
          'Invalid semver "$version": non-numeric component "$component"');
    }
  }

  // Parse components to integers
  final parsedComponents = <int>[];
  for (int i = 0; i < components.length; i++) {
    parsedComponents.add(int.parse(components[i]));
  }

  // Take only first three components, pad with zeros if needed
  final result = <int>[0, 0, 0];
  for (int i = 0; i < 3 && i < parsedComponents.length; i++) {
    result[i] = parsedComponents[i];
  }

  return result;
}
