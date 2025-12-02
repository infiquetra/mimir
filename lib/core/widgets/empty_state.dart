import 'package:flutter/material.dart';

/// Reusable empty state widget for displaying when no data is available.
///
/// Shows an icon, heading, description, and optional action button.
class EmptyState extends StatelessWidget {
  /// Icon to display.
  final IconData icon;

  /// Main heading text.
  final String heading;

  /// Description text explaining the empty state.
  final String description;

  /// Optional action button (e.g., "Retry", "Add Character").
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.heading,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Icon(
              icon,
              size: 64,
              color: Colors.white.withAlpha(128),
            ),
            const SizedBox(height: 16),

            // Heading
            Text(
              heading,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(179),
              ),
              textAlign: TextAlign.center,
            ),

            // Optional action button
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
