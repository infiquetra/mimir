/// Utility functions for semantic version comparison.
///
/// Follows Semantic Versioning 2.0.0 specification for version comparison.
int compareSemVer(String a, String b) {
  final versionA = _parseVersion(a);
  final versionB = _parseVersion(b);

  // Compare major version
  final majorComparison = versionA[0].compareTo(versionB[0]);
  if (majorComparison != 0) return majorComparison;

  // Compare minor version
  final minorComparison = versionA[1].compareTo(versionB[1]);
  if (minorComparison != 0) return minorComparison;

  // Compare patch version
  return versionA[2].compareTo(versionB[2]);
}

/// Parses a semantic version string into a list of three integers.
///
/// Validates that the input is non-empty and all components are numeric.
/// Throws FormatException with the original input if validation fails.
List<int> _parseVersion(String input) {
  final trimmedInput = input.trim();
  
  // Check for empty or whitespace-only input
  if (trimmedInput.isEmpty) {
    throw FormatException('Invalid version string: "$input"', input);
  }

  // Split the version string by dots
  final components = trimmedInput.split('.');
  
  // Parse each component as integer
  final parsedComponents = <int>[];
  for (int i = 0; i < components.length && i < 3; i++) {
    final component = components[i];
    if (!_isNumeric(component)) {
      throw FormatException('Invalid version string: "$input"', input);
    }
    parsedComponents.add(int.parse(component));
  }
  
  // Pad with zeros if fewer than 3 components
  while (parsedComponents.length < 3) {
    parsedComponents.add(0);
  }
  
  return parsedComponents;
}

/// Checks if a string represents a valid non-negative integer.
bool _isNumeric(String s) {
  if (s.isEmpty) return false;
  for (int i = 0; i < s.length; i++) {
    if (!_isDigit(s.codeUnitAt(i))) return false;
  }
  return true;
}

/// Checks if a code unit represents a digit character.
bool _isDigit(int codeUnit) {
  return codeUnit >= 0x30 && codeUnit <= 0x39; // '0' to '9'
}