/// Utility functions for formatting values.

/// Formats a byte count into a human-readable string using binary units.
///
/// Uses 1024-based units (B, KB, MB, GB, TB). Values above 1 TB are scaled
/// within TB (e.g., '1.5 TB'). Decimal places are trimmed:
/// - Whole numbers: no decimal (e.g., '2 KB')
/// - One decimal place when needed (e.g., '1.5 MB')
/// - Up to two decimal places (e.g., '1.25 KB')
///
/// Examples:
/// - `formatBytes(0)` → `'0 B'`
/// - `formatBytes(1024)` → `'1 KB'`
/// - `formatBytes(1536)` → `'1.5 KB'`
/// - `formatBytes(-1536)` → `'-1.5 KB'`
/// - `formatBytes(1099511627776)` → `'1 TB'`
/// - `formatBytes(1649267441664)` → `'1.5 TB'`
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const threshold = 1024;

  // Handle zero specially to avoid negative zero issues
  if (bytes == 0) {
    return '0 B';
  }

  // Work with absolute value for unit calculation
  final absBytes = bytes.abs();
  final isNegative = bytes < 0;

  // Determine the appropriate unit
  var unitIndex = 0;
  var value = absBytes.toDouble();

  // Find the right unit by repeatedly dividing by threshold
  // Stop at TB (last unit) even for values above 1 TB
  while (value >= threshold && unitIndex < units.length - 1) {
    value /= threshold;
    unitIndex++;
  }

  // Format with up to 2 decimal places
  // Floor to 2 decimal places to avoid premature rounding up
  double floored = (value * 100).floor() / 100;
  String formatted = floored.toStringAsFixed(2);

  // Trim trailing zeros and potential trailing dot
  if (formatted.contains('.')) {
    formatted = formatted.replaceAll(RegExp(r'0+$'), '');
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
  }

  // Apply negative sign if needed
  if (isNegative) {
    formatted = '-$formatted';
  }

  return '$formatted ${units[unitIndex]}';
}
