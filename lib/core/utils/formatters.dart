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

  final absBytes = bytes.abs();
  final sign = bytes < 0 ? '-' : '';

  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  int unitIndex = 0;
  double value = absBytes.toDouble();

  // Scale the value appropriately
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  // Handle special formatting for the near-threshold case to avoid rounding errors
  // For example, 1048575 bytes should be 1023.99 KB, not 1024 KB
  String formatted;
  if (unitIndex == 0) {
    formatted = value.toInt().toString();
  } else {
    // For KB and above, we floor instead of round to prevent crossing thresholds
    // Convert to fixed-point arithmetic to avoid floating-point errors
    final scaledValueInt = (value * 100).toInt();
    final flooredValue = scaledValueInt ~/ 100; // Integer division
    final decimalPart = scaledValueInt % 100;

    if (decimalPart == 0) {
      formatted = flooredValue.toString();
    } else {
      // Format with up to 2 decimals, removing trailing zeros
      String decimalStr = decimalPart.toString().padLeft(2, '0');
      if (decimalStr.endsWith('0')) {
        decimalStr = decimalStr.substring(0, decimalStr.length - 1);
      }
      formatted = '$flooredValue.$decimalStr';
    }
  }

  return '$sign$formatted ${units[unitIndex]}';
}
