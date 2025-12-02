import 'package:flutter/material.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/eve_card.dart';

/// Individual balance card widget for displaying wallet balances.
///
/// Displays an icon, label, and value with EVE Online styling.
/// Can be customized with different colors for ISK, PLEX, LP, etc.
class BalanceCard extends StatelessWidget {
  /// The label text (e.g., "ISK", "PLEX", "LP Corporations").
  final String label;

  /// The value to display (e.g., "1,445,229,330" or "806").
  final String value;

  /// Icon to display (optional).
  final IconData? icon;

  /// Accent color for the card border and icon background.
  final Color accentColor;

  /// Text color for the value.
  final Color valueColor;

  /// Whether this card is loading.
  final bool isLoading;

  /// Optional trailing widget (e.g., info button).
  final Widget? trailing;

  const BalanceCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accentColor = EveColors.evePrimary,
    this.valueColor = Colors.white,
    this.isLoading = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return EveCard(
      glowColor: accentColor,
      glowIntensity: 0.3,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row with icon and label
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: accentColor.withAlpha(77),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withAlpha(179),
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),

          // Value
          isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accentColor,
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: accentColor.withAlpha(102),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
        ],
      ),
    );
  }
}
