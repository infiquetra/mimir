// Utility functions for semantic version comparison.

/// Compares two semantic version strings and returns a comparator-style integer.
///
/// Returns negative if [a] < [b], zero if [a] == [b], positive if [a] > [b].
///
/// Accepts versions of the form MAJOR.MINOR.PATCH (e.g., '1.2.3').
/// Short versions like '1.2' are treated as '1.2.0' (missing components default to zero).
/// Extra trailing components beyond patch are ignored (e.g., '1.2.3.4' is treated as '1.2.3').
///
/// Throws [FormatException] if either input is malformed (empty, whitespace-only,
/// or contains non-numeric components). The exception message includes the
/// offending input string verbatim.
///
/// Examples:
/// - `compareSemVer('1.2.3', '1.2.3')` → `0`
/// - `compareSemVer('1.2.3', '1.2.4')` → negative
/// - `compareSemVer('1.10.0', '1.2.0')` → positive (numeric comparison)
/// - `compareSemVer('1.2', '1.2.0')` → `0` (short form pads with zero)
/// - `compareSemVer('1.2.3.4', '1.2.3')` → `0` (extra components ignored)
int compareSemVer(String a, String b) {
  final aComponents = _parseSemVer(a);
  final bComponents = _parseSemVer(b);

  // Compare major, then minor, then patch
  for (int i = 0; i < 3; i++) {
    final comparison = aComponents[i].compareTo(bComponents[i]);
    if (comparison != 0) {
      return comparison;
    }
  }
  return 0;
}

/// Parses a semantic version string into exactly three numeric components.
///
/// Returns a list of three integers: [major, minor, patch].
/// Short versions are padded with zeros (e.g., '1.2' → [1, 2, 0]).
/// Extra trailing components are ignored (e.g., '1.2.3.4' → [1, 2, 3]).
///
/// Throws [FormatException] if the input is empty, whitespace-only,
/// or contains non-numeric components. The exception message includes
/// the original input string.
List<int> _parseSemVer(String input) {
  // Reject empty or whitespace-only input
  if (input.trim().isEmpty) {
    throw FormatException('Invalid semantic version: $input');
  }

  final parts = input.split('.');

  // Parse exactly three components (major, minor, patch)
  final components = <int>[];
  for (int i = 0; i < 3; i++) {
    if (i < parts.length) {
      final parsed = int.tryParse(parts[i]);
      if (parsed == null) {
        throw FormatException('Invalid semantic version: $input');
      }
      components.add(parsed);
    } else {
      // Pad missing components with 0
      components.add(0);
    }
  }

  return components;
}
