/// Utility functions for formatting values.

/// Formats a number of bytes into a human-readable string.
/// 
/// Use 1024 as the unit base. Rounds to a maximum of 2 decimal places,
/// removing trailing zeros. Units: B, KB, MB, GB, TB.
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
    formatted = value.toStringAsFixed(2);
    
    // Handle rounding rollover (e.g., 1023.999 -> 1024.00)
    if (double.parse(formatted) == 1024.0 && unitIndex < units.length - 1) {
      value = 1.0;
      unitIndex++;
      formatted = value.toStringAsFixed(2);
    }

    // Trim trailing zeros and decimal point if not needed
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
