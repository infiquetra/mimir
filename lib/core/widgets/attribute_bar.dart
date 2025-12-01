import 'package:flutter/material.dart';

/// Displays a character attribute as a labeled progress bar.
///
/// Used for displaying Intelligence, Memory, Willpower, Perception, and Charisma.
/// Shows the attribute name, value, and a visual bar representation.
class AttributeBar extends StatelessWidget {
  /// Attribute name (e.g., "Intelligence", "Memory").
  final String name;

  /// Attribute value (typically 5-50).
  final int value;

  /// Icon to display next to the attribute name.
  final IconData icon;

  /// Color for the progress bar.
  final Color? color;

  /// Maximum possible attribute value for bar visualization.
  /// EVE Online attributes can go up to ~50 with implants and remaps.
  final int maxValue;

  const AttributeBar({
    super.key,
    required this.name,
    required this.value,
    required this.icon,
    this.color,
    this.maxValue = 50,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = color ?? theme.colorScheme.primary;
    final progress = (value / maxValue).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Icon
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),

          // Attribute name
          SizedBox(
            width: 100,
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Progress bar
          Expanded(
            child: Stack(
              children: [
                // Background bar
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Progress bar
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Value label
          SizedBox(
            width: 50,
            child: Text(
              '$value points',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
