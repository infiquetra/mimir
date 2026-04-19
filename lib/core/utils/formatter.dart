/// Utility functions for formatting various data types.
library;

/// Formats a byte value into a human readable string with appropriate units.
///
/// Examples:
/// ```dart
/// formatBytes(0); // returns '0 B'
/// formatBytes(1); // returns '1 B'
/// formatBytes(1023); // returns '1023 B'
/// formatBytes(1024); // returns '1.00 KB'
/// formatBytes(1048576); // returns '1.00 MB'
/// ```
String formatBytes(int bytes) {
  if (bytes < 0) {
    throw ArgumentError.value(bytes, 'bytes', 'Must be non-negative');
  }

  const List<String> units = ['B', 'KB', 'MB', 'GB', 'TB'];
  int index = 0;
  double value = bytes.toDouble();

  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }

  // For bytes (index == 0) show no decimal places
  // For larger units show 2 decimal places
  if (index == 0) {
    return '${value.toInt()} ${units[index]}';
  } else {
    return '${value.toStringAsFixed(2)} ${units[index]}';
  }
}