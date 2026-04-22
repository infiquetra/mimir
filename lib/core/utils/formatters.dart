/// Utility functions for formatting values.

/// Formats a byte count into a human-readable string using binary units.
///
/// Scales through B, KB, MB, GB, and TB. To maintain readability for very
/// large values, counts exceeding 1024 TB do not transition to a new unit;
/// they continue to use the 'TB' suffix while scaling numerically (e.g., '1024 TB').
///
/// Examples:
/// - `formatBytes(0)` → `'0 B'`
/// - `formatBytes(512)` → `'512 B'`
/// - `formatBytes(1024)` → `'1 KB'`
/// - `formatBytes(1536)` → `'1.5 KB'`
/// - `formatBytes(1048576)` → `'1 MB'`
/// - `formatBytes(-2048)` → `'-2 KB'`
String formatBytes(int bytes) {
  if (bytes == 0) return '0 B';

  final isNegative = bytes < 0;
  final absBytes = bytes.abs();
  final sign = isNegative ? '-' : '';
  
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = absBytes.toDouble();
  var unitIndex = 0;

  // Scale the value while it's >= 1024 and we haven't reached TB yet
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  // Format with up to two decimal places, then trim trailing zeros
  String formattedValue;
  if (unitIndex == 0) {
    // For bytes, show as integer
    formattedValue = value.toInt().toString();
  } else {
    // For other units, floor to prevent crossing thresholds and show with up to 2 decimal places
    // Convert to fixed-point arithmetic to avoid floating-point errors
    final scaledValueInt = (value * 100).floor(); // Floor instead of round
    final flooredValue = scaledValueInt ~/ 100; // Integer division
    final decimalPart = scaledValueInt % 100;

    if (decimalPart == 0) {
      formattedValue = flooredValue.toString();
    } else {
      // Format with up to 2 decimals, removing trailing zeros
      String decimalStr = decimalPart.toString().padLeft(2, '0');
      if (decimalStr.endsWith('0')) {
        decimalStr = decimalStr.substring(0, decimalStr.length - 1);
      }
      formattedValue = '$flooredValue.$decimalStr';
    }
  }

  return '$sign$formattedValue ${units[unitIndex]}';
}

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
  return formatBytes(bytes);
}