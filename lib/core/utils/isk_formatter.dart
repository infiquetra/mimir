import 'package:intl/intl.dart';

/// Formats ISK (in-game currency) values for display.
///
/// Accepts a [num] value representing ISK amount and returns a formatted
/// string with commas as thousand separators, 2 decimal places, and " ISK" suffix.
///
/// Handles edge cases:
/// - Non-finite values (NaN, Infinity) return "Invalid ISK amount"
/// - Negative zero is normalized to positive zero
/// - Rounding is handled by NumberFormat for consistency
///
/// Examples:
/// - formatIsk(1234567.89) → "1,234,567.89 ISK"
/// - formatIsk(0) → "0.00 ISK"
/// - formatIsk(-500.5) → "-500.50 ISK"
/// - formatIsk(1000000000000.0) → "1,000,000,000,000.00 ISK"
/// - formatIsk(double.nan) → "Invalid ISK amount"
/// - formatIsk(double.infinity) → "Invalid ISK amount"
String formatIsk(num amount) {
  // Handle non-finite values
  if (!amount.isFinite) {
    return 'Invalid ISK amount';
  }

  // Use NumberFormat for consistent currency-style formatting
  // This handles rounding, thousands separators, and decimal places
  final formatter = NumberFormat('#,##0.00', 'en_US');
  var formatted = formatter.format(amount);

  // Handle negative zero case: NumberFormat preserves -0.00, but we want 0.00
  if (formatted == '-0.00') {
    formatted = '0.00';
  }

  return '$formatted ISK';
}
