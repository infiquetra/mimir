import 'package:intl/intl.dart';

/// Cached NumberFormat for ISK formatting to avoid allocation on every call.
final _iskFormatter = NumberFormat('#,##0.00', 'en_US');

/// Formats an ISK amount with proper number formatting.
///
/// Examples:
/// - 1234567.89 → "1,234,567.89 ISK"
/// - -50000 → "-50,000.00 ISK"
/// - 1000000000 → "1,000,000,000.00 ISK"
/// - NaN → "0.00 ISK"
/// - Infinity → "0.00 ISK"
String formatIsk(double amount) {
  // Handle non-finite doubles
  if (!amount.isFinite) {
    return '0.00 ISK';
  }
  
  // Normalize negative zero to positive zero
  if (amount == 0.0) {
    amount = 0.0;
  }
  
  return '${_iskFormatter.format(amount)} ISK';
}

/// Formats an ISK amount in a compact form.
///
/// Examples:
/// - 1234 → "1.23K ISK"
/// - 1234567 → "1.23M ISK"
/// - 1234567890 → "1.23B ISK"
/// - 1234567890000 → "1.23T ISK"
/// - 999999 → "1.00M ISK" (correctly rolls over at boundary)
/// - NaN → "0.00 ISK"
/// - Infinity → "0.00 ISK"
String formatIskCompact(double amount) {
  // Handle non-finite doubles
  if (!amount.isFinite) {
    return '0.00 ISK';
  }
  
  final absAmount = amount.abs();
  final sign = amount < 0 ? '-' : '';

  String suffix;
  double divisor;
  
  // Determine the appropriate unit, checking thresholds in descending order
  if (absAmount >= 1e12) {
    suffix = 'T';
    divisor = 1e12;
  } else if (absAmount >= 1e9) {
    suffix = 'B';
    divisor = 1e9;
  } else if (absAmount >= 1e6) {
    suffix = 'M';
    divisor = 1e6;
  } else if (absAmount >= 1e3) {
    suffix = 'K';
    divisor = 1e3;
  } else {
    // No suffix for values < 1000
    final formatted = absAmount.toStringAsFixed(2);
    return '$sign$formatted ISK';
  }
  
  // Divide and round to 2 decimal places
  final divided = absAmount / divisor;
  final rounded = (divided * 100).round() / 100;
  
  // Handle rollover: if rounding pushes us to 1000 or more, promote to next unit
  if (rounded >= 1000) {
    // Promote to next unit
    if (suffix == 'K') {
      suffix = 'M';
      divisor = 1e6;
    } else if (suffix == 'M') {
      suffix = 'B';
      divisor = 1e9;
    } else if (suffix == 'B') {
      suffix = 'T';
      divisor = 1e12;
    } else if (suffix == 'T') {
      // Already at max unit, just use the large number
      final formatted = rounded.toStringAsFixed(2);
      return '$sign$formatted$suffix ISK';
    }
    // Recalculate with new divisor
    final newDivided = absAmount / divisor;
    final newRounded = (newDivided * 100).round() / 100;
    final formatted = newRounded.toStringAsFixed(2);
    return '$sign$formatted$suffix ISK';
  }
  
  final formatted = rounded.toStringAsFixed(2);
  return '$sign$formatted$suffix ISK';
}

/// Formats a duration into a human-readable string.
///
/// Examples:
/// - Duration(days: 2, hours: 4, minutes: 32) → "2d 4h 32m"
/// - Duration(hours: 4, minutes: 15) → "4h 15m"
/// - Duration(minutes: 32) → "32m"
/// - Duration(seconds: 30) → "< 1m"
/// - Duration.zero → "0m"
/// - Negative duration → "0m"
String formatDuration(Duration duration) {
  // Handle negative durations
  if (duration.isNegative) {
    return '0m';
  }

  // Handle zero duration
  if (duration == Duration.zero) {
    return '0m';
  }

  final days = duration.inDays;
  final hours = duration.inHours % 24;
  final minutes = duration.inMinutes % 60;

  // Handle sub-minute durations
  if (days == 0 && hours == 0 && minutes == 0) {
    return '< 1m';
  }

  final parts = <String>[];
  if (days > 0) parts.add('${days}d');
  if (hours > 0) parts.add('${hours}h');
  if (minutes > 0) parts.add('${minutes}m');

  return parts.join(' ');
}

/// Formats a snake_case string into Title Case.
///
/// Useful for displaying ESI reference types in a human-readable format.
///
/// Examples:
/// - "player_trading" → "Player Trading"
/// - "corporation_account_withdrawal" → "Corporation Account Withdrawal"
/// - "bounty_prizes" → "Bounty Prizes"
/// - "PLAYER_TRADING" → "Player Trading" (normalizes case)
/// - "__foo__bar" → "Foo Bar" (filters empty segments)
String formatSnakeCase(String input) {
  return input
      .split('_')
      .where((word) => word.isNotEmpty)  // Filter empty segments
      .map((word) =>
          '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}
