import 'package:intl/intl.dart';

/// Formats an ISK amount with proper number formatting.
///
/// Examples:
/// - 1234567.89 → "1,234,567.89 ISK"
/// - -50000 → "-50,000.00 ISK"
/// - 1000000000 → "1,000,000,000.00 ISK"
String formatIsk(double amount) {
  final formatter = NumberFormat('#,##0.00', 'en_US');
  return '${formatter.format(amount)} ISK';
}

/// Formats an ISK amount in a compact form.
///
/// Examples:
/// - 1234 → "1.23K ISK"
/// - 1234567 → "1.23M ISK"
/// - 1234567890 → "1.23B ISK"
/// - 1234567890000 → "1.23T ISK"
String formatIskCompact(double amount) {
  final absAmount = amount.abs();
  final sign = amount < 0 ? '-' : '';

  String formatted;
  if (absAmount >= 1e12) {
    formatted = '${(absAmount / 1e12).toStringAsFixed(2)}T';
  } else if (absAmount >= 1e9) {
    formatted = '${(absAmount / 1e9).toStringAsFixed(2)}B';
  } else if (absAmount >= 1e6) {
    formatted = '${(absAmount / 1e6).toStringAsFixed(2)}M';
  } else if (absAmount >= 1e3) {
    formatted = '${(absAmount / 1e3).toStringAsFixed(2)}K';
  } else {
    formatted = absAmount.toStringAsFixed(2);
  }

  return '$sign$formatted ISK';
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
String formatSnakeCase(String input) {
  return input
      .split('_')
      .map((word) =>
          word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
      .join(' ');
}
