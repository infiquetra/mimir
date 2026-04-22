/// Utility functions for formatting values.

/// Formats a byte count into a human-readable string using binary units.
///
/// Uses 1024-based units (B, KB, MB, GB, TB). Values above 1 TB are scaled
/// within TB (e.g., '1.5 TB').
///
/// Examples:
/// - `formatBytes(0)` → `'0 B'`
/// - `formatBytes(1024)` → `'1 KB'`
/// - `formatBytes(1536)` → `'1.5 KB'`
/// - `formatBytes(-2048)` → `'-2 KB'`
String formatBytes(int bytes) {
  if (bytes == 0) return '0 B';

  final absBytes = bytes.abs();
  final sign = bytes < 0 ? '-' : '';

  if (absBytes < 1024) {
    return '$sign$absBytes B';
  }

  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  int unitIndex = 0;
  double value = absBytes.toDouble();

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  String formattedNumber = value.toStringAsFixed(2);
  if (formattedNumber.endsWith('.00')) {
    formattedNumber = formattedNumber.substring(0, formattedNumber.length - 3);
  } else if (formattedNumber.endsWith('0')) {
    formattedNumber = formattedNumber.substring(0, formattedNumber.length - 1);
  }

  return '$sign$formattedNumber ${units[unitIndex]}';
}
