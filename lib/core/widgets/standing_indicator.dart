import 'package:flutter/material.dart';

/// Provides color-coded background tinting based on EVE standing values.
///
/// Standings in EVE Online range from -10 (hostile) to +10 (excellent).
/// This helper provides colors for row backgrounds to indicate standing level.
class StandingIndicator {
  /// Returns a background color tint based on standing value.
  ///
  /// Standing ranges:
  /// - Red tint: -10 to -5 (hostile/enemy)
  /// - Orange tint: -5 to -1 (disliked/poor)
  /// - Neutral: -1 to +1 (neutral)
  /// - Light green tint: +1 to +5 (liked/good)
  /// - Dark green tint: +5 to +10 (excellent)
  static Color getBackgroundColor(
    double standing, {
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (standing <= -5.0) {
      // Hostile/Enemy: Red tint
      return isDark
          ? Colors.red.withValues(alpha: 0.15)
          : Colors.red.withValues(alpha: 0.08);
    } else if (standing < -1.0) {
      // Disliked/Poor: Orange tint
      return isDark
          ? Colors.orange.withValues(alpha: 0.15)
          : Colors.orange.withValues(alpha: 0.08);
    } else if (standing >= 5.0) {
      // Excellent: Dark green tint
      return isDark
          ? Colors.green.shade700.withValues(alpha: 0.20)
          : Colors.green.shade600.withValues(alpha: 0.10);
    } else if (standing > 1.0) {
      // Liked/Good: Light green tint
      return isDark
          ? Colors.lightGreen.withValues(alpha: 0.15)
          : Colors.lightGreen.withValues(alpha: 0.08);
    } else {
      // Neutral: No tint
      return Colors.transparent;
    }
  }

  /// Returns a text color that contrasts well with the standing background.
  static Color getTextColor(
    double standing, {
    required BuildContext context,
  }) {
    // For subtle background tints, normal text colors work fine
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Returns a formatted standing value string.
  ///
  /// Example: 2.34 → "+2.3", -5.67 → "-5.7"
  static String formatStanding(double standing) {
    final formatted = standing.toStringAsFixed(1);
    if (standing > 0) {
      return '+$formatted';
    }
    return formatted;
  }

  /// Returns a descriptive label for the standing level.
  static String getStandingLabel(double standing) {
    if (standing <= -5.0) return 'Hostile';
    if (standing < -1.0) return 'Poor';
    if (standing >= 5.0) return 'Excellent';
    if (standing > 1.0) return 'Good';
    return 'Neutral';
  }
}
