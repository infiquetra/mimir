/// Utility functions for formatting values.

/// Formats a byte count into a human-readable string using binary units.
///
/// Uses 1024-based units (B, KB, MB, GB, TB). Values above 1 TB are scaled
/// within TB (e.g., '1024 TB').
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

  String formatted = value.toStringAsFixed(2);
  if (formatted.endsWith('.00')) {
    formatted = formatted.substring(0, formatted.length - 3);
  } else if (formatted.endsWith('0')) {
    formatted = formatted.substring(0, formatted.length - 1);
  }

  return '$sign$formatted ${units[unitIndex]}';
}
