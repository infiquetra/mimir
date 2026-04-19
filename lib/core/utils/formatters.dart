/// Formatting utilities for display values.

/// Formats a byte count into a human-readable string using binary units
/// (B, KB, MB, GB, TB) with automatic unit selection.
///
/// Examples:
/// - 0 -> "0 B"
/// - 512 -> "512 B"
/// - 1024 -> "1 KB"
/// - 1536 -> "1.5 KB"
/// - -2048 -> "-2 KB"
/// - Values >= 1024 TB scale within TB (e.g., "1024 TB")
///
/// [bytes] The byte count to format. Can be negative.
/// Returns A formatted string like "1.5 MB" or "-2.3 GB".
String formatBytes(int bytes) {
  if (bytes == 0) {
    return '0 B';
  }

  final isNegative = bytes < 0;
  final absBytes = bytes.abs();

  // Binary units: B, KB, MB, GB, TB
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];

  // Calculate the appropriate unit index
  // index = floor(log(base) of bytes) where base is 1024
  int unitIndex = 0;
  var scaledBytes = absBytes.toDouble();

  while (scaledBytes >= 1024 && unitIndex < units.length - 1) {
    scaledBytes /= 1024;
    unitIndex++;
  }

  // Format to 2 decimal places, then trim trailing zeros
  final formatted = _trimTrailingZeros(scaledBytes.toStringAsFixed(2));
  final prefix = isNegative ? '-' : '';

  return '$prefix$formatted ${units[unitIndex]}';
}

/// Removes trailing zeros from a decimal string and the trailing dot if present.
///
/// Examples:
/// - "1.50" -> "1.5"
/// - "1.00" -> "1"
/// - "1.23" -> "1.23"
/// - "0.00" -> "0"
String _trimTrailingZeros(String s) {
  // Remove trailing zeros
  while (s.contains('.') && s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  // Remove trailing dot if present
  if (s.endsWith('.')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
