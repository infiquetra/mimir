/// Utility functions for semantic version comparison.
///
/// Implements comparison of semantic version strings according to SemVer 2.0.0
/// specification, with support for major.minor.patch format.
library semver;

/// Compares two semantic version strings.
///
/// Parses each input string into major.minor.patch components and compares
/// them numerically from left to right.
///
/// Returns:
/// * a negative integer if [a] is less than [b]
/// * zero if [a] equals [b]
/// * a positive integer if [a] is greater than [b]
///
/// Examples:
/// ```dart
/// compareSemVer('1.2.3', '1.2.3'); // 0
/// compareSemVer('1.2.3', '1.2.4'); // negative
/// compareSemVer('1.10.0', '1.2.0'); // positive
/// compareSemVer('1.2', '1.2.0'); // 0 (short form padding)
/// ```
///
/// Throws [FormatException] for malformed input:
/// * Empty or whitespace-only strings
/// * Non-numeric components (e.g., '1.2.a')
int compareSemVer(String a, String b) {
  final componentsA = _parseSemVerComponents(a);
  final componentsB = _parseSemVerComponents(b);

  // Compare major, then minor, then patch
  for (int i = 0; i < 3; i++) {
    final result = componentsA[i].compareTo(componentsB[i]);
    if (result != 0) return result;
  }

  return 0;
}

/// Parses a semantic version string into exactly three integer components.
///
/// Normalizes by:
/// * Taking only the first three dot-separated components
/// * Padding with zeros if fewer than three components exist
/// * Converting components to integers
///
/// Throws [FormatException] for invalid input strings.
List<int> _parseSemVerComponents(String input) {
  if (input.trim().isEmpty) {
    throw FormatException('Invalid semantic version: "$input"');
  }

  final parts = input.split('.');
  
  // Take only first three components, pad with zeros if needed
  final components = <int>[];
  for (int i = 0; i < 3; i++) {
    final part = i < parts.length ? parts[i] : '0';
    
    // Validate that component is numeric
    if (!_isNumeric(part)) {
      throw FormatException('Invalid semantic version: "$input"');
    }
    
    components.add(int.parse(part));
  }
  
  return components;
}

/// Checks if a string represents a valid non-negative integer.
bool _isNumeric(String str) {
  if (str.isEmpty) return false;
  for (int i = 0; i < str.length; i++) {
    if (!_isDigit(str.codeUnitAt(i))) return false;
  }
  return true;
}

/// Checks if a code unit represents a digit (0-9).
bool _isDigit(int codeUnit) {
  return codeUnit >= 0x30 && codeUnit <= 0x39;
}