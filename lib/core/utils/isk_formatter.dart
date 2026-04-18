import 'package:intl/intl.dart';

/// File-level formatter instance to avoid per-call allocation overhead.
/// Locale is intentionally fixed to 'en_US' for consistent EVE-style numeric display
/// across all regions (commas for thousands, period for decimal).
/// The ' ISK' suffix is appended manually to maintain explicit control over formatting.
final _iskFormatter = NumberFormat('#,##0.00', 'en_US');

/// Formats ISK (in-game currency) values for display.
///
/// Accepts a [num] value representing ISK amount and returns a formatted
/// string with commas as thousand separators, 2 decimal places, and " ISK" suffix.
///
/// Handles edge cases:
/// - Non-finite values (NaN, Infinity) return "Invalid ISK amount"
/// - Negative zero and values rounding to zero are normalized to positive "0.00 ISK"
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

  // Normalize negative zero and near-zero values before formatting.
  // Values with magnitude < 0.005 round to zero and should display as positive.
  // This is more robust than checking the formatted string output.
  if (amount.abs() < 0.005) {
    amount = 0;
  }

  final formatted = _iskFormatter.format(amount);
  return '$formatted ISK';
}
