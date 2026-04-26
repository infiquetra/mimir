/// Utility functions for semantic version comparison.
///
/// Implements a comparator for semantic version strings following the
/// MAJOR.MINOR.PATCH format as defined by semver.org.

library semver;

/// Compares two semantic version strings.
///
/// Returns a negative integer if [a] is less than [b], zero if they are equal,
/// or a positive integer if [a] is greater than [b].
///
/// Handles version strings in the form MAJOR.MINOR.PATCH, padding missing
/// components with zero and ignoring components beyond patch.
///
/// Throws [FormatException] for malformed input (non-numeric components,
/// empty strings, or whitespace-only strings) with the offending input
/// included in the exception message.
///
/// Examples:
/// ```dart
/// compareSemVer('1.2.3', '1.2.3'); // 0
/// compareSemVer('1.2.3', '1.2.4'); // negative
/// compareSemVer('1.10.0', '1.2.0'); // positive (numeric comparison)
/// compareSemVer('1.2', '1.2.0'); // 0
/// compareSemVer('1.2.3.4', '1.2.3'); // 0
/// ```
int compareSemVer(String a, String b) {
  final aComponents = _parseSemVer(a);
  final bComponents = _parseSemVer(b);

  // Compare major, then minor, then patch
  for (int i = 0; i < 3; i++) {
    final result = aComponents[i].compareTo(bComponents[i]);
    if (result != 0) {
      return result;
    }
  }

  return 0;
}

/// Parses a semantic version string into a normalized [major, minor, patch] list.
///
/// Validates that the input is not empty or whitespace-only and that all
/// components are numeric. Ignores components beyond the third.
List<int> _parseSemVer(String input) {
  // Check for empty or whitespace-only input
  if (input.isEmpty || input.trim().isEmpty) {
    throw FormatException('Invalid semantic version: $input', input);
  }

  final components = input.split('.');
  final result = <int>[0, 0, 0]; // [major, minor, patch]

  // Process up to 3 components (major, minor, patch)
  for (int i = 0; i < 3 && i < components.length; i++) {
    final component = components[i];
    
    // Validate that component is numeric
    final parsed = int.tryParse(component);
    if (parsed == null) {
      throw FormatException('Invalid semantic version: $input', input);
    }
    
    result[i] = parsed;
  }

  return result;
}