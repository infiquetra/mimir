/// Utility functions for formatting values.

/// Formats a byte count into a human-readable string using binary units.
///
/// Uses binary (1024-based) units: B, KB, MB, GB, TB.
/// Values above TB continue to use the TB suffix while scaling numerically.
/// Decimal places are trimmed: exact units render as "1 KB", "1 MB";
/// fractional values keep up to 2 decimals with trailing zeros removed.
///
/// Examples:
/// - `formatBytes(0)` → `'0 B'`
/// - `formatBytes(512)` → `'512 B'`
/// - `formatBytes(1024)` → `'1 KB'`
/// - `formatBytes(1536)` → `'1.5 KB'`
/// - `formatBytes(1048576)` → `'1 MB'`
/// - `formatBytes(-2048)` → `'-2 KB'`
String formatBytes(int bytes) {
  if (bytes == 0) {
    return '0 B';
  }

  final absBytes = bytes.abs();
  final sign = bytes < 0 ? '-' : '';

  if (absBytes < 1024) {
    return '$sign$absBytes B';
  }

  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  int unitIndex = 0;
  int power = 1; // 1024 ^ unitIndex

  // Determine appropriate unit
  int scaled = absBytes;
  while (scaled >= 1024 && unitIndex < units.length - 1) {
    power *= 1024;
    scaled = absBytes ~/ power;
    unitIndex++;
  }

  // Remainder within the current unit
  int remainder = absBytes % power;
  String formatted;
  if (remainder == 0) {
    formatted = scaled.toString();
  } else {
    // Compute hundredths (two decimal digits) by integer division
    int hundredths = (remainder * 100) ~/ power;
    // Round up if fractional part is >= 0.995 of the next hundredth
    // (i.e. remainder/power >= 0.9995 → remainder*1000/power >= 999.5 → >= 1000)
    bool roundUp = (remainder * 1000) ~/ power >= 999;
    if (roundUp) {
      scaled++;
      // If rounding landed on or past the unit boundary (e.g. 1023.99 KB → 1024 KB = 1 MB),
      // promote to the next unit. Also promote when the two-decimal representation is 99.xx,
      // which rounds to the next integer in display (e.g. 1023.99 → "1024.00"). If already
      // at TB cap, stay in current unit.
      if ((scaled >= power || hundredths >= 99) && unitIndex < units.length - 1) {
        unitIndex++;
        power *= 1024;
        // Rounded value is exactly 1 of the new unit
        scaled = 1;
        remainder = 0;
      }
      if (remainder == 0) {
        formatted = scaled.toString();
      } else {
        int newHundredths = (remainder * 100) ~/ power;
        if (newHundredths == 0) {
          formatted = scaled.toString();
        } else if (newHundredths % 10 == 0) {
          formatted = '$scaled.${newHundredths ~/ 10}';
        } else {
          formatted = '$scaled.${newHundredths.toString().padLeft(2, '0')}';
        }
      }
    } else if (hundredths == 0) {
      formatted = scaled.toString();
    } else if (hundredths % 10 == 0) {
      // Single decimal digit
      formatted = '$scaled.${hundredths ~/ 10}';
    } else {
      // Two decimal digits, ensure leading zero
      formatted = '$scaled.${hundredths.toString().padLeft(2, '0')}';
    }
  }

  return '$sign$formatted ${units[unitIndex]}';
}