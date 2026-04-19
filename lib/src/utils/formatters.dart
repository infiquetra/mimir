/// Formats a byte size into a human-readable string.
///
/// Converts bytes into the appropriate unit (B, KiB, MiB, GiB, TiB) based on the magnitude.
/// Uses binary (1024) for unit conversions. Handles negative values and zero.
///
/// Rules:
/// - Bytes (B): whole numbers only, no decimal places
/// - KiB and above: up to 2 decimal places, trailing zeros trimmed
/// - After rounding to 2 decimal places, if the value is 1024 or higher and a larger
///   unit exists, it is promoted to the next unit (e.g., 1023.999 KiB → 1 MiB, not "1024 KiB")
/// - Values beyond TiB stay in TiB (e.g., 1024^5 bytes = 1024 TiB)
/// - Negative values preserve their sign
///
/// Examples:
/// ```dart
/// formatBytes(0)           // '0 B'
/// formatBytes(512)         // '512 B'
/// formatBytes(1024)        // '1 KiB'
/// formatBytes(1536)        // '1.5 KiB'
/// formatBytes(-1536)       // '-1.5 KiB'
/// formatBytes(1048576)     // '1 MiB'
/// formatBytes(1073741824)  // '1 GiB'
/// formatBytes(1048575)     // '1 MiB' (rounds to 1024 KiB, promoted to MiB)
/// ```
String formatBytes(int bytes) {
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
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

  // Format decPart as 2-digit string to preserve leading zeros (e.g., "01", "05")
  // Then trim trailing zeros
  String decStr = decPart.toString().padLeft(2, '0');
  
  // Trim trailing zeros
  while (decStr.endsWith('0')) {
    decStr = decStr.substring(0, decStr.length - 1);
  }

  return '$intPart.$decStr';
}
