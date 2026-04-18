/// Formats ISK (in-game currency) values for display.
///
/// Accepts a [double] value representing ISK amount and returns a formatted
/// string with commas as thousand separators, 2 decimal places, and " ISK" suffix.
///
/// Examples:
/// - formatIsk(1234567.89) → "1,234,567.89 ISK"
/// - formatIsk(0) → "0.00 ISK"
/// - formatIsk(-500.5) → "-500.50 ISK"
/// - formatIsk(1000000000000.0) → "1,000,000,000,000.00 ISK"
String formatIsk(double amount) {
  // Round to 2 decimal places
  final rounded = (amount * 100).roundToDouble() / 100;

  // Format with commas and 2 decimal places
  final formatted = rounded.toStringAsFixed(2);

  // Add commas as thousand separators
  final parts = formatted.split('.');
  final integerPart = parts[0];
  final decimalPart = parts.length > 1 ? parts[1] : '00';

  // Handle negative numbers
  final isNegative = integerPart.startsWith('-');
  final absInteger = isNegative ? integerPart.substring(1) : integerPart;

  // Add commas every 3 digits from the right
  final buffer = StringBuffer();
  for (int i = 0; i < absInteger.length; i++) {
    if (i > 0 && (absInteger.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(absInteger[i]);
  }

  final integerWithCommas = buffer.toString();
  final sign = isNegative ? '-' : '';

  return '$sign$integerWithCommas.$decimalPart ISK';
}
