/// Utility functions for formatting values.

/// Formats a number of bytes into a human-readable string with units (B, KB, MB, GB, TB).
///
/// Uses 1024 as the unit base. Truncates to 2 decimal places and removes trailing zeros.
String formatBytes(int bytes) {
  if (bytes == 0) return '0 B';

  final absBytes = bytes.abs();
  final sign = bytes < 0 ? '-' : '';

  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  int unitIndex = 0;
  double value = absBytes.toDouble();

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  String formatted;
  if (unitIndex == 0) {
    formatted = value.toInt().toString();
  } else {
    // Handle rounding by floored truncation to 2 decimal places
    // This prevents 1023.999... from rounding up to 1024.00 and causing unit rollover issues.
    double truncatedValue = (value * 100).floorToDouble() / 100.0;
    formatted = truncatedValue.toStringAsFixed(2);
    // remove trailing .0 or .00 or just the last 0
    if (formatted.endsWith('.00')) {
      formatted = formatted.substring(0, formatted.length - 3);
    } else if (formatted.endsWith('.0')) {
      formatted = formatted.substring(0, formatted.length - 2);
    } else if (formatted.contains('.') && formatted.endsWith('0')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
  }

  return '$sign$formatted ${units[unitIndex]}';
}
