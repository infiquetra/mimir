/// Formats a byte size into a human-readable string.
///
/// Converts bytes into the appropriate unit (B, KB, MB, GB, TB) based on the magnitude.
/// Uses binary (1024) for unit conversions. Handles negative values and zero.
///
/// Rules:
/// - Bytes (B): whole numbers only, no decimal places
/// - KB and above: up to 2 decimal places, trailing zeros trimmed
/// - After rounding to 2 decimal places, if the value is 1024 or higher and a larger
///   unit exists, it is promoted to the next unit (e.g., 1023.999 KB → 1 MB, not "1024 KB")
/// - Values beyond TB stay in TB (e.g., 1024^5 bytes = 1024 TB)
/// - Negative values preserve their sign
///
/// Examples:
/// ```dart
/// formatBytes(0)           // '0 B'
/// formatBytes(512)         // '512 B'
/// formatBytes(1024)        // '1 KB'
/// formatBytes(1536)        // '1.5 KB'
/// formatBytes(-1536)       // '-1.5 KB'
/// formatBytes(1048576)     // '1 MB'
/// formatBytes(1073741824)  // '1 GB'
/// formatBytes(1048575)     // '1 MB' (rounds to 1024 KB, promoted to MB)
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

  // Determine the appropriate unit using integer arithmetic
  int unitIndex = 0;
  int divisor = 1;
  while ((absBytes ~/ base) >= divisor && unitIndex < units.length - 1) {
    divisor *= base;
    unitIndex++;
  }

  // For bytes, use whole numbers only
  if (unitIndex == 0) {
    final result = '${absBytes} ${units[unitIndex]}';
    return isNegative ? '-$result' : result;
  }

  // Calculate value in current unit with integer math using BigInt to avoid overflow
  // We need: scaledValue100 = round(absBytes * 100 / divisor) to 2 decimal places
  // Using BigInt for intermediate calculation to handle very large values
  BigInt bigAbsBytes = BigInt.from(absBytes);
  BigInt bigDivisor = BigInt.from(divisor);
  BigInt scaled100Big = (bigAbsBytes * BigInt.from(1000)) ~/ bigDivisor;
  int scaledValue100 = ((scaled100Big + BigInt.from(5)) ~/ BigInt.from(10)).toInt();

  // After rounding, if we're at 1024 or higher, promote
  if (scaledValue100 >= 102400 && unitIndex < units.length - 1) {
    unitIndex++;
    divisor *= base;
    // Recalculate for the new unit using BigInt
    bigDivisor = BigInt.from(divisor);
    scaled100Big = (bigAbsBytes * BigInt.from(1000)) ~/ bigDivisor;
    scaledValue100 = ((scaled100Big + BigInt.from(5)) ~/ BigInt.from(10)).toInt();
  }

  // Format with up to 2 decimal places and trim trailing zeros
  final String formatted = _formatScaled(scaledValue100);
  final result = '$formatted ${units[unitIndex]}';
  return isNegative ? '-$result' : result;
}

/// Formats a value that's been pre-scaled by 100.
/// value100 = value * 100. Returns trimmed string like "1023.99" or "2".
String _formatScaled(int value100) {
  int intPart = value100 ~/ 100;
  int decPart = value100 % 100;

  if (decPart == 0) {
    return '$intPart';
  }

  // Trim trailing zeros
  while (decPart % 10 == 0) {
    decPart ~/= 10;
  }

  return '$intPart.$decPart';
}
