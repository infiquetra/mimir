/// Utility functions for semantic version comparison.
///
/// Implements comparison of semantic version strings following
/// the MAJOR.MINOR.PATCH format as defined by SemVer 2.0.0.
library semver;

/// Compares two semantic version strings.
///
/// Parses each input string into [major, minor, patch] components,
/// then compares numerically each component in sequence.
///
/// Examples:
/// - `compareSemVer('1.2.3', '1.2.3')` → `0`
/// - `compareSemVer('1.2.3', '1.2.4')` → negative
/// - `compareSemVer('1.10.0', '1.2.0')` → positive (numeric, not lexicographic)
/// - `compareSemVer('2.0.0', '1.99.99')` → positive
/// - `compareSemVer('1.2', '1.2.0')` → `0` (short form pads with zero)
/// - `compareSemVer('1.2.3.4', '1.2.3')` → `0` (extra components ignored)
/// - `compareSemVer('1.2.a', '1.2.3')` → throws [FormatException]
///
/// Parameters:
/// - [a]: A semantic version string
/// - [b]: A semantic version string
///
/// Returns:
/// - Negative integer if [a] is less than [b]
/// - Zero if [a] is equal to [b]
/// - Positive integer if [a] is greater than [b]
///
/// Throws:
/// - [FormatException] if either input cannot be parsed as valid semantic version
int compareSemVer(String a, String b) {
  final List<int> aComponents = _parseSemVer(a);
  final List<int> bComponents = _parseSemVer(b);

  // Compare each component in sequence
  for (int i = 0; i < 3; i++) {
    final int comparison = aComponents[i].compareTo(bComponents[i]);
    if (comparison != 0) {
      return comparison;
    }
  }

  return 0;
}

/// Parses a semantic version string into [major, minor, patch] components.
///
/// Takes only the first three components from a split on '.', and pads
/// any missing components with 0.
///
/// Throws [FormatException] if any component is not a valid integer
/// or if the input string is empty.
List<int> _parseSemVer(String version) {
  if (version.isEmpty) {
    throw FormatException('Invalid semantic version: Empty string "$version"', version);
  }

  final List<String> parts = version.split('.');
  
  // Take at most 3 components, pad with '0' if fewer than 3
  final List<String> components = List<String>.filled(3, '0');
  for (int i = 0; i < 3 && i < parts.length; i++) {
    components[i] = parts[i];
  }

  // Convert each component to integer, validating along the way
  final List<int> result = List<int>.filled(3, 0);
  for (int i = 0; i < 3; i++) {
    final String component = components[i];
    if (component.isEmpty) {
      throw FormatException('Invalid semantic version: Empty component "$component" in "$version"', version);
    }
    
    try {
      result[i] = int.parse(component);
    } catch (e) {
      throw FormatException('Invalid semantic version: Non-numeric component "$component" in "$version"', version);
    }
  }

  return result;
}