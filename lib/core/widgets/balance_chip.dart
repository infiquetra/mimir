import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/eve_colors.dart';
import '../theme/eve_spacing.dart';
import '../theme/eve_typography.dart';

/// Compact horizontal chip for displaying balance values.
///
/// Designed for the Wallet screen to replace bulky balance cards with
/// a streamlined horizontal row that fits in 36px height.
///
/// ```dart
/// BalanceChip(
///   icon: Icons.account_balance_wallet,
///   label: 'ISK',
///   value: 1523456789.0,
///   color: EveColors.photonBlue,
/// )
/// ```
class BalanceChip extends StatelessWidget {
  const BalanceChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.compact = false,
  });

  /// Icon to display (e.g., currency symbol, wallet icon).
  final IconData icon;

  /// Label text (e.g., 'ISK', 'PLEX', 'LP').
  final String label;

  /// Numeric value to display.
  final double value;

  /// Optional accent color for icon/border.
  final Color? color;

  /// Whether to use ultra-compact mode (smaller text, tighter padding).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accentColor = color ?? EveColors.photonBlue;
    final formatter = NumberFormat('#,##0.##', 'en_US');

    // Format value based on magnitude
    String formattedValue;
    if (value >= 1000000000) {
      // Billions
      formattedValue = '${formatter.format(value / 1000000000)}B';
    } else if (value >= 1000000) {
      // Millions
      formattedValue = '${formatter.format(value / 1000000)}M';
    } else if (value >= 1000) {
      // Thousands
      formattedValue = '${formatter.format(value / 1000)}K';
    } else {
      formattedValue = formatter.format(value);
    }

    return Container(
      height: compact ? 32 : EveSpacing.balanceChipHeight,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? EveSpacing.md : EveSpacing.lg,
        vertical: compact ? EveSpacing.sm : EveSpacing.md,
      ),
      decoration: BoxDecoration(
        color: EveColors.surfaceDefault,
        borderRadius: BorderRadius.circular(EveSpacing.chipRadius),
        border: Border.all(
          color: accentColor.withAlpha(77), // 30% opacity
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon with accent color background
          Container(
            padding: EdgeInsets.all(compact ? EveSpacing.xs : EveSpacing.sm),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(26), // 10% opacity
              borderRadius: BorderRadius.circular(EveSpacing.sm),
            ),
            child: Icon(
              icon,
              size: compact ? EveSpacing.iconXs : EveSpacing.iconSm,
              color: accentColor,
            ),
          ),

          SizedBox(width: compact ? EveSpacing.sm : EveSpacing.md),

          // Label
          Text(
            label,
            style: compact
                ? EveTypography.labelSmall(color: EveColors.textSecondary)
                : EveTypography.labelMedium(color: EveColors.textSecondary),
          ),

          SizedBox(width: compact ? EveSpacing.xs : EveSpacing.sm),

          // Value with monospace font
          Text(
            formattedValue,
            style: compact
                ? EveTypography.dataSmall(color: EveColors.textPrimary)
                : EveTypography.dataMedium(color: EveColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Row of balance chips for multiple currencies.
///
/// Used in Wallet screen to display ISK, PLEX, LP, and EverMarks
/// in a single horizontal row that takes only 36-40px height.
///
/// ```dart
/// BalanceChipRow(
///   balances: {
///     'ISK': 1523456789.0,
///     'PLEX': 150,
///     'LP': 5234567,
///   },
/// )
/// ```
class BalanceChipRow extends StatelessWidget {
  const BalanceChipRow({
    super.key,
    required this.balances,
    this.compact = false,
  });

  /// Map of label to value (e.g., {'ISK': 1500000000, 'PLEX': 150}).
  final Map<String, double> balances;

  /// Whether to use compact mode.
  final bool compact;

  // Icon mapping for common currencies
  static const Map<String, IconData> _iconMap = {
    'ISK': Icons.account_balance_wallet,
    'PLEX': Icons.verified,
    'LP': Icons.stars,
    'EverMarks': Icons.military_tech,
  };

  // Color mapping for common currencies
  static const Map<String, Color> _colorMap = {
    'ISK': EveColors.photonBlue,
    'PLEX': EveColors.photonCyan,
    'LP': EveColors.amarr,
    'EverMarks': EveColors.gallente,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? EveSpacing.sm : EveSpacing.md,
      runSpacing: compact ? EveSpacing.sm : EveSpacing.md,
      children: balances.entries.map((entry) {
        final label = entry.key;
        final value = entry.value;
        final icon = _iconMap[label] ?? Icons.monetization_on;
        final color = _colorMap[label] ?? EveColors.photonBlue;

        return BalanceChip(
          icon: icon,
          label: label,
          value: value,
          color: color,
          compact: compact,
        );
      }).toList(),
    );
  }
}
