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
/// - Duration.zero → "0m"
String formatDuration(Duration duration) {
  final days = duration.inDays;
  final hours = duration.inHours % 24;
  final minutes = duration.inMinutes % 60;

  final parts = <String>[];
  if (days > 0) parts.add('${days}d');
  if (hours > 0) parts.add('${hours}h');
  if (minutes > 0 || parts.isEmpty) parts.add('${minutes}m');

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

/// Formats a byte count into a human-readable string with binary units.
///
/// Uses binary units (B, KB, MB, GB, TB) where 1 KB = 1024 B.
/// - Bytes (B) are shown as whole numbers only
/// - KB and above show up to 2 decimal places with trailing zeros trimmed
/// - Negative values are prefixed with minus sign
/// - Values beyond TB are scaled within TB (e.g., 1024 TB, 1048576 TB)
/// - Values near unit boundaries are promoted (e.g., 1023.999 KB → 1 MB)
///
/// Examples:
/// - 0 → "0 B"
/// - 512 → "512 B"
/// - 1024 → "1 KB"
/// - 1536 → "1.5 KB"
/// - 1048576 → "1 MB"
/// - -1024 → "-1 KB"
/// - 1099511627776 → "1 TB"
String formatBytes(int bytes) {
  if (bytes == 0) return '0 B';

  final sign = bytes < 0 ? '-' : '';
  final absBytes = bytes.abs();

  // Define units with their thresholds and suffixes
  const units = [
    (threshold: 1, suffix: 'B', showDecimals: false),
    (threshold: 1024, suffix: 'KB', showDecimals: true),
    (threshold: 1024 * 1024, suffix: 'MB', showDecimals: true),
    (threshold: 1024 * 1024 * 1024, suffix: 'GB', showDecimals: true),
    (threshold: 1024 * 1024 * 1024 * 1024, suffix: 'TB', showDecimals: true),
  ];

  // Find the appropriate unit
  var unitIndex = 0;
  for (var i = 1; i < units.length; i++) {
    if (absBytes >= units[i].threshold) {
      unitIndex = i;
    } else {
      break;
    }
  }

  final unit = units[unitIndex];
  final scaledValue = absBytes / unit.threshold;

  // Format based on unit type
  String formatted;
  if (!unit.showDecimals) {
    // Bytes: whole numbers only
    formatted = absBytes.toString();
  } else {
    // KB and above: up to 2 decimal places, trim trailing zeros
    // Check if rounding would push us to the next unit
    final rounded = (scaledValue * 100).round() / 100;
    if (rounded >= 1024 && unitIndex < units.length - 1) {
      // Promote to next unit
      final nextUnit = units[unitIndex + 1];
      final nextValue = absBytes / nextUnit.threshold;
      formatted = _trimTrailingZeros(nextValue.toStringAsFixed(2));
      return '$sign$formatted ${nextUnit.suffix}';
    }
    formatted = _trimTrailingZeros(rounded.toStringAsFixed(2));
  }

  return '$sign$formatted ${unit.suffix}';
}

/// Trims trailing zeros and decimal point from a number string.
///
/// Examples:
/// - "1.00" → "1"
/// - "1.50" → "1.5"
/// - "1.55" → "1.55"
String _trimTrailingZeros(String value) {
  if (!value.contains('.')) return value;

  // Remove trailing zeros
  var result = value;
  while (result.endsWith('0')) {
    result = result.substring(0, result.length - 1);
  }

  // Remove trailing decimal point if present
  if (result.endsWith('.')) {
    result = result.substring(0, result.length - 1);
  }

  return result;
}
