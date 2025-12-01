import 'package:flutter/material.dart';

/// Displays a character attribute as a simple row (EVE-style).
///
/// Used for displaying Intelligence, Memory, Willpower, Perception, and Charisma.
/// Shows icon, attribute name, and value in a minimal design without progress bars.
class AttributeBar extends StatelessWidget {
  /// Attribute name (e.g., "Intelligence", "Memory").
  final String name;

  /// Attribute value (typically 5-50).
  final int value;

  /// Icon to display next to the attribute name.
  final IconData icon;

  /// Color for the icon.
  final Color? color;

  const AttributeBar({
    super.key,
    required this.name,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Icon
          Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
          const SizedBox(width: 12),

          // Attribute name
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyMedium,
            ),
          ),

          // Value label
          Text(
            '$value points',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
