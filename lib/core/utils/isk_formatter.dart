import 'package:intl/intl.dart';

/// File-level formatter instance to avoid per-call allocation overhead.
/// Locale is intentionally fixed to 'en_US' for consistent EVE-style numeric display
/// across all regions (commas for thousands, period for decimal).
/// The ' ISK' suffix is appended manually to maintain explicit control over formatting.
///
/// NOTE: This formatter is designed for UI display only. For business logic that needs
/// to handle invalid inputs differently, validate inputs before calling formatIsk().
final _iskFormatter = NumberFormat('#,##0.00', 'en_US');

/// Formats ISK (in-game currency) values for display.
///
/// Accepts a [num] value representing ISK amount and returns a formatted
/// string with commas as thousand separators, 2 decimal places, and " ISK" suffix.
///
/// Throws [ArgumentError] for non-finite values (NaN, Infinity) to separate
/// validation concerns from formatting. Callers should validate inputs before
/// formatting if they need different error handling behavior.
///
/// Handles edge cases:
/// - Non-finite values (NaN, Infinity) throw [ArgumentError]
/// - Negative zero and values rounding to zero are normalized to positive "0.00 ISK"
/// - Rounding is handled by NumberFormat for consistency
///
/// Examples:
/// - formatIsk(1234567.89) → "1,234,567.89 ISK"
/// - formatIsk(0) → "0.00 ISK"
/// - formatIsk(-500.5) → "-500.50 ISK"
/// - formatIsk(1000000000000.0) → "1,000,000,000,000.00 ISK"
///
/// Throws:
/// - [ArgumentError] if [amount] is NaN or infinite
String formatIsk(num amount) {
  // Reject non-finite values early - validation is separate from formatting
  if (!amount.isFinite) {
    throw ArgumentError.value(
      amount,
      'amount',
      'ISK amount must be a finite number, got ${amount.toString()}',
    );
  }

  // Normalize negative zero and near-zero values before formatting.
  // Threshold of 0.005 is derived from 2-decimal rounding: any value with
  // magnitude < 0.005 will round to 0.00, so we normalize to positive zero
  // for consistent display semantics.
  if (amount.abs() < 0.005) {
    amount = 0;
  }

  final formatted = _iskFormatter.format(amount);
  return '$formatted ISK';
}
