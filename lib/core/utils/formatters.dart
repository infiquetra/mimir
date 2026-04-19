/// Utility functions for formatting values.
class Formatters {
  /// Formats bytes as human-readable strings using binary units (1024-based).
  ///
  /// [bytes] - The number of bytes to format (can be negative).
  ///
  /// Returns formatted string with appropriate unit (B, KB, MB, GB, TB).
  ///
  /// Examples:
  /// - formatBytes(0) → "0 B"
  /// - formatBytes(512) → "512 B"
  /// - formatBytes(1024) → "1 KB"
  /// - formatBytes(1536) → "1.5 KB"
  /// - formatBytes(1048576) → "1 MB"
  /// - formatBytes(-2048) → "-2 KB"
  static String formatBytes(int bytes) {
    if (bytes == 0) return '0 B';

    const List<String> units = ['B', 'KB', 'MB', 'GB', 'TB'];
    final int absBytes = bytes.abs();
    int unitIndex = 0;
    num size = absBytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    // Format the number to remove unnecessary decimals
    String formattedSize;
    if (size == size.roundToDouble()) {
      formattedSize = size.round().toString();
    } else {
      // Round to 2 decimal places
      double rounded = (size * 100).round() / 100;
      formattedSize = rounded.toStringAsFixed(2);
      // Remove trailing zeros
      formattedSize = formattedSize.replaceAll(RegExp(r'\.?0*$'), '');
    }

    return '${bytes < 0 ? '-' : ''}$formattedSize ${units[unitIndex]}';
  }
}
