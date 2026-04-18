/// Utility functions for formatting EVE Online ISK (currency) values.
///
/// ISK is the in-game currency of EVE Online. Values are typically large,
/// so this utility provides consistent formatting with appropriate suffixes.
library;

/// Formats an ISK value with appropriate suffix (B, M, K) based on magnitude.
///
/// Examples:
/// - 1500000000 -> '1.50B'
/// - 5000000 -> '5.00M'
/// - 2500 -> '2.50K'
/// - 100 -> '100'
///
/// Parameters:
/// - [value]: The ISK value to format (must be non-negative)
/// - [decimals]: Number of decimal places to show (default: 2)
/// - [includeSuffix]: Whether to include the 'ISK' suffix (default: true)
///
/// Returns a formatted string representation of the ISK value.
String formatIsk(int value, {int decimals = 2, bool includeSuffix = true}) {
  if (value < 0) {
    throw ArgumentError('ISK value must be non-negative, got: $value');
  }

  final suffix = includeSuffix ? ' ISK' : '';

  if (value >= 1000000000) {
    // Billions
    return '${(value / 1000000000).toStringAsFixed(decimals)}B$suffix';
  } else if (value >= 1000000) {
    // Millions
    return '${(value / 1000000).toStringAsFixed(decimals)}M$suffix';
  } else if (value >= 1000) {
    // Thousands
    return '${(value / 1000).toStringAsFixed(decimals)}K$suffix';
  } else {
    // Raw value
    return '$value$suffix';
  }
}

/// Formats an ISK value as a compact string without suffix.
///
/// Useful for display in tight spaces where the context already indicates ISK.
/// Uses the same magnitude-based formatting as [formatIsk] but omits the suffix.
String formatIskCompact(int value, {int decimals = 2}) {
  return formatIsk(value, decimals: decimals, includeSuffix: false);
}
