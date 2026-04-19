/// Utility functions for formatting various data types.
/// Formats a byte value into a human readable string with appropriate units.
///
/// This function uses binary scaling (1024-based) with IEC unit prefixes.
/// Bytes are shown without decimal places, while larger units show 2 decimal places.
///
/// Examples:
/// ```dart
/// formatBytes(0); // returns '0 B'
/// formatBytes(1); // returns '1 B'
/// formatBytes(1023); // returns '1023 B'
/// formatBytes(1024); // returns '1.00 KiB'
/// formatBytes(1048576); // returns '1.00 MiB'
/// formatBytes(1073741824); // returns '1.00 GiB'
/// formatBytes(1099511627776); // returns '1.00 TiB'
/// formatBytes(1125899906842624); // returns '1.00 PiB'
/// ```
String formatBytes(int bytes) {
  if (bytes < 0) {
    throw ArgumentError.value(bytes, 'bytes', 'Must be non-negative');
  }

  const List<String> units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB'];
  int index = 0;
  double value = bytes.toDouble();

  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }

  // Check for rounding edge case where value rounds to 1024.00
  if (index > 0 && (value * 100).round() >= 102400) {
    if (index < units.length - 1) {
      value /= 1024;
      index++;
    }
  }

  // For bytes (index == 0) show no decimal places
  // For larger units show 2 decimal places
  if (index == 0) {
    return '${value.toInt()} ${units[index]}';
  } else {
    return '${value.toStringAsFixed(2)} ${units[index]}';
  }
}
