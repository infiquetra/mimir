/// Utility functions for formatting durations into human-readable strings.
library formatters;

/// Formats a [Duration] into a compact human-readable string.
///
/// The formatter:
/// * Uses the two largest non-zero units (e.g., days + hours, or hours + minutes)
/// * Omits trailing zero units
/// * Shows "<1s" for sub-second durations
/// * Prepends "-" for negative durations
///
/// Examples:
/// * `formatDuration(Duration(hours: 2, minutes: 15))` → `"2h 15m"`
/// * `formatDuration(Duration(minutes: 45))` → `"45m"`
/// * `formatDuration(Duration(days: 3, hours: 4))` → `"3d 4h"`
/// * `formatDuration(Duration(seconds: 12))` → `"12s"`
/// * `formatDuration(Duration.zero)` → `"0s"`
/// * `formatDuration(Duration(milliseconds: 500))` → `"<1s"`
/// * `formatDuration(Duration(minutes: -5))` → `"-5m"`
String formatDuration(Duration duration) {
  if (duration == Duration.zero) {
    return '0s';
  }

  final isNegative = duration.isNegative;
  final absDuration = duration.abs();

  // Handle sub-second durations
  if (absDuration < const Duration(seconds: 1)) {
    return isNegative ? '<1s' : '<1s';
  }

  // Extract components
  final days = absDuration.inDays;
  final hours = absDuration.inHours % 24;
  final minutes = absDuration.inMinutes % 60;
  final seconds = absDuration.inSeconds % 60;

  final StringBuffer buffer = StringBuffer();

  if (isNegative) {
    buffer.write('-');
  }

  // Determine the two largest non-zero units to display
  if (days > 0) {
    buffer.write('${days}d');
    if (hours > 0) {
      buffer.write(' ${hours}h');
    } else if (minutes > 0) {
      buffer.write(' ${minutes}m');
    } else if (seconds > 0) {
      buffer.write(' ${seconds}s');
    }
  } else if (hours > 0) {
    buffer.write('${hours}h');
    if (minutes > 0) {
      buffer.write(' ${minutes}m');
    } else if (seconds > 0) {
      buffer.write(' ${seconds}s');
    }
  } else if (minutes > 0) {
    buffer.write('${minutes}m');
    if (seconds > 0) {
      buffer.write(' ${seconds}s');
    }
  } else {
    // Only seconds left
    buffer.write('${seconds}s');
  }

  return buffer.toString();
}
