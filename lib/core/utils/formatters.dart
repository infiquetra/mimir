/// Utility functions for formatting various data types.
library formatters;

/// Formats bytes into a human-readable string with appropriate units.
///
/// Converts bytes to the largest unit (B, KB, MB, GB, TB) that keeps the value >= 1.
/// Trims trailing zeros from decimal places (e.g., 1.00 KB becomes 1 KB).
/// Handles negative numbers with a minus prefix.
/// 
/// Example:
/// ```dart
/// formatBytes(0);      // '0 B'
/// formatBytes(1);      // '1 B'
/// formatBytes(1023);   // '1023 B'
/// formatBytes(1024);   // '1 KB'
/// formatBytes(1536);   // '1.5 KB'
/// formatBytes(-1024);  // '-1 KB'
/// formatBytes(1024 * 1024);  // '1 MB'
/// ```
String formatBytes(int bytes) {
  // Handle negative values by working with absolute value and adding minus sign
  final isNegative = bytes < 0;
  var absBytes = isNegative ? -bytes : bytes;
  
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const divider = 1024;
  
  // Handle special case for 0 bytes
  if (absBytes == 0) return '0 B';
  
  var value = absBytes.toDouble();
  var unitIndex = 0;
  
  // Divide until we get to an appropriately sized unit or reach max unit
  while (value >= divider && unitIndex < units.length - 1) {
    value /= divider;
    unitIndex++;
  }
  
  // Format the value with appropriate decimal places and trim trailing zeros
  String formattedValue;
  if (value == value.roundToDouble()) {
    // Whole number, show without decimal places
    formattedValue = value.round().toString();
  } else {
    // Fractional number, show up to 2 decimal places
    formattedValue = value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0*$'), '');
  }
  
  // Add minus sign for negative values
  if (isNegative) {
    formattedValue = '-$formattedValue';
  }
  
  return '$formattedValue ${units[unitIndex]}';
}