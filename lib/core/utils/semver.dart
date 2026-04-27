/// Utility functions for semantic version comparison.
library;

/// Parses a semantic version string into exactly three numeric components.
///
/// [version] must be a non-empty, non-whitespace-only string using dot-separated
/// numeric components. Malformed input throws [FormatException] with the
/// offending value included in the message.
///
/// Behavior:
/// - Short versions (e.g., '1.2') are padded with zeros → [1, 2, 0].
/// - Extra components (e.g., '1.2.3.4') are truncated → [1, 2, 3].
/// - Non-numeric components throw [FormatException].
/// - Empty or whitespace-only strings throw [FormatException].
List<int> _parseSemVerComponents(String version) {
  // Validate non-empty input
  if (version.isEmpty) {
    throw FormatException('Malformed semantic version: $version');
  }

  // Validate not purely whitespace
  if (version.trim().isEmpty) {
    throw FormatException('Malformed semantic version: $version');
  }

  final parts = version.split('.');

  // Consider only the first three components
  final componentsToParse = parts.take(3);
  final parsed = <int>[];

  for (final component in componentsToParse) {
    final value = int.tryParse(component);
    if (value == null) {
      throw FormatException('Malformed semantic version: $version');
    }
    parsed.add(value);
  }

  // Pad with zeros for missing components
  while (parsed.length < 3) {
    parsed.add(0);
  }

  return parsed;
}

/// Compares two semantic-version strings.
///
/// Returns a comparator-style integer: negative if [a] < [b], zero if [a] == [b],
/// positive if [a] > [b]. The magnitude of the result is not specified; only
/// the sign matters.
///
/// Accepts versions of the form `MAJOR.MINOR.PATCH` (e.g., `1.2.3`). Comparison
/// is numeric (not lexicographic), so `1.10.0 > 1.2.0`.
///
/// Short versions (e.g., `1.2`) are treated as `1.2.0`. Extra trailing
/// components (e.g., `1.2.3.4`) are treated as `1.2.3`.
///
/// Throws [FormatException] if either input is malformed: empty string,
/// whitespace-only string, or contains non-numeric components. The exception
/// message includes the offending input verbatim.
///
/// Examples:
/// - `compareSemVer('1.2.3', '1.2.3')` → `0`
/// - `compareSemVer('1.2.3', '1.2.4')` → negative
/// - `compareSemVer('1.10.0', '1.2.0')` → positive
/// - `compareSemVer('1.2', '1.2.0')` → `0`
/// - `compareSemVer('1.2.3.4', '1.2.3')` → `0`
int compareSemVer(String a, String b) {
  final aComponents = _parseSemVerComponents(a);
  final bComponents = _parseSemVerComponents(b);

  for (var i = 0; i < 3; i++) {
    final comparison = aComponents[i].compareTo(bComponents[i]);
    if (comparison != 0) {
      return comparison;
    }
  }

  return 0;
}
