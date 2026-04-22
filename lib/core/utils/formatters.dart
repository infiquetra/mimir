/// Utility functions for formatting values.

/// Renders byte counts as human-readable strings using binary units.
///
/// Uses B, KB, MB, GB, and TB with 1024-based scaling. Trims trailing
/// zeros for clean display. Preserves negative signs when applicable.
///
/// Examples:
/// - `humanizeBytes(0)` → `'0 B'`
/// - `humanizeBytes(512)` → `'512 B'`
/// - `humanizeBytes(1024)` → `'1 KB'`
/// - `humanizeBytes(1536)` → `'1.5 KB'`
/// - `humanizeBytes(1048576)` → `'1 MB'`
/// - `humanizeBytes(-2048)` → `'-2 KB'`
/// - `humanizeBytes(1024^5)` → `'1024 TB'`
String humanizeBytes(int bytes) {
  if (bytes == 0) return '0 B';

  final isNegative = bytes < 0;
  final absBytes = isNegative ? -bytes : bytes; // Handle negative without using abs()
  final sign = isNegative ? '-' : '';
  
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = absBytes.toDouble();
  var unitIndex = 0;

  // Scale the value while it's >= 1024 and we haven't reached TB yet
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  // Handle edge case where rounding causes value to reach 1024 threshold after formatting
  // which incorrectly displays as (1024 X) when it should promote to the next unit
  if (unitIndex < units.length - 1 && value.toStringAsFixed(2) == '1024.00') {
    value = 1.0;
    unitIndex++; // Promote to the next unit
  }

  // Format with up to two decimal places, then trim trailing zeros
  String formattedValue;
  if (unitIndex == 0) {
    // For bytes, show as integer
    formattedValue = value.toInt().toString();
  } else {
    // For other units, show with up to 2 decimal places
    formattedValue = value.toStringAsFixed(2);
    
    // Remove trailing zeros and decimal point if not needed
    if (formattedValue.endsWith('.00')) {
      formattedValue = formattedValue.substring(0, formattedValue.length - 3);
    } else if (formattedValue.endsWith('0') && formattedValue.contains('.')) {
      formattedValue = formattedValue.substring(0, formattedValue.length - 1);
    }
  }

  return '$sign$formattedValue ${units[unitIndex]}';
}