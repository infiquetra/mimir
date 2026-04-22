/// Utility functions for formatting values.
 
/// Formats a number of bytes into a human-readable string with units (B, KB, MB, GB, TB).
/// Use 1024 as the unit base. Rounds to 2 decimal places and removes trailing zeros.
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
    // Round to 2 decimal places.
    // We use toStringAsFixed(2) which performs rounding.
    formatted = value.toStringAsFixed(2);
    
    // Handle cases where rounding up causes unit rollover (e.g., 1023.999 -> 1024.00)
    if (double.tryParse(formatted) == 1024.0) {
      if (unitIndex < units.length - 1) {
        value = 1.0;
        unitIndex++;
        formatted = value.toStringAsFixed(2);
      }
    }

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
