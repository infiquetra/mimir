/// Formats a byte size into a human-readable string.
///
/// Converts bytes into the appropriate unit (B, KB, MB, GB, TB) based on the magnitude.
/// Uses binary (1024) for unit conversions. Handles negative values and zero.
///
/// Rules:
/// - Bytes (B): whole numbers only, no decimal places
/// - KB and above: up to 2 decimal places, trailing zeros trimmed
/// - Values at or above 1024 of a unit are promoted to the next unit
///   (e.g., 1024 KB becomes 1 MB, not "1024 KB")
/// - Values beyond TB stay in TB (e.g., 1024^5 bytes = 1024 TB)
/// - Negative values preserve their sign
///
/// Examples:
/// ```dart
/// formatBytes(0)        // '0 B'
/// formatBytes(512)      // '512 B'
/// formatBytes(1024)     // '1 KB'
/// formatBytes(1536)       // '1.5 KB'
/// formatBytes(-1536)      // '-1.5 KB'
/// formatBytes(1048576)    // '1 MB'
/// formatBytes(1073741824) // '1 GB'
/// ```
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const int base = 1024;

  // Handle zero case
  if (bytes == 0) {
    return '0 B';
  }

  // Work with absolute value for magnitude calculation
  final bool isNegative = bytes < 0;
  final int absBytes = bytes.abs();

  // Calculate the appropriate unit index
  int unitIndex = 0;
  double value = absBytes.toDouble();

  while (value >= base && unitIndex < units.length - 1) {
    value /= base;
    unitIndex++;
  }

  // For bytes, use whole numbers only
  if (unitIndex == 0) {
    final result = '${value.toInt()} ${units[unitIndex]}';
    return isNegative ? '-$result' : result;
  }

  // For KB and above, use up to 2 decimal places, trimming trailing zeros
  // Check if rounding would push us to the next unit
  if (value >= base && unitIndex < units.length - 1) {
    value /= base;
    unitIndex++;
  }

  // Format with up to 2 decimal places and trim trailing zeros
  String formattedValue = value.toStringAsFixed(2);
  formattedValue = formattedValue.replaceAll(RegExp(r'\.?0+$'), '');

  final result = '$formattedValue ${units[unitIndex]}';
  return isNegative ? '-$result' : result;
}
