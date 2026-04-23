/// Utility functions for semantic version comparison.

/// Compares two semantic version strings and returns a comparator-style integer.
///
/// Returns a negative value if [a] < [b], zero if equal, or a positive value if [a] > [b].
///
/// Versions are compared numerically component by component (major, minor, patch).
/// Short versions (e.g., '1.2') are padded with zeros (becomes '1.2.0').
/// Extra components beyond patch are ignored (e.g., '1.2.3.4' treated as '1.2.3').
///
/// Throws [FormatException] if either version string is malformed:
/// - Empty or whitespace-only string
/// - Non-numeric component (e.g., '1.2.a')
/// - Empty component (e.g., '1..2' or '.1.2')
///
/// The exception message includes the offending input string verbatim.
///
/// Examples:
/// - `compareSemVer('1.2.3', '1.2.3')` → `0`
/// - `compareSemVer('1.2.3', '1.2.4')` → negative
/// - `compareSemVer('1.10.0', '1.2.0')` → positive (numeric comparison)
/// - `compareSemVer('1.2', '1.2.0')` → `0` (short form pads with zero)
/// - `compareSemVer('1.2.3.4', '1.2.3')` → `0` (extra components ignored)
int compareSemVer(String a, String b) {
  final aParts = _parseVersion(a);
  final bParts = _parseVersion(b);

  // Compare major
  final majorCompare = aParts[0].compareTo(bParts[0]);
  if (majorCompare != 0) return majorCompare;

  // Compare minor
  final minorCompare = aParts[1].compareTo(bParts[1]);
  if (minorCompare != 0) return minorCompare;

  // Compare patch
  return aParts[2].compareTo(bParts[2]);
}

/// Parses a version string into exactly three numeric components [major, minor, patch].
///
/// Throws [FormatException] with the original input in the message if:
/// - Input is empty or whitespace-only
/// - Any of the first three components is empty or non-numeric
List<int> _parseVersion(String input) {
  // Validate input is not empty or whitespace-only
  if (input.trim().isEmpty) {
    throw FormatException('Invalid version string: "$input" (empty or whitespace-only)');
  }

  final parts = input.split('.');
  final result = <int>[];

  for (int i = 0; i < 3; i++) {
    if (i >= parts.length) {
      // Pad missing components with zero
      result.add(0);
    } else {
      final component = parts[i];
      // Check for empty component (e.g., '1..2' or '.1.2')
      if (component.isEmpty) {
        throw FormatException('Invalid version string: "$input" (empty component at position $i)');
      }
      // Check for non-numeric component
      final parsed = int.tryParse(component);
      if (parsed == null) {
        throw FormatException('Invalid version string: "$input" (non-numeric component: "$component")');
      }
      result.add(parsed);
    }
  }

  return result;
}
