/// Feature tour step for onboarding (Step 2).
library;

import 'package:flutter/material.dart';

/// Step 2: Feature overview.
///
/// Showcases the main features of the app:
/// - Dashboard: Character overview and status
/// - Skills: Skill queue monitoring
/// - Wallet: Balance and transaction history
class FeatureTourStep extends StatelessWidget {
  const FeatureTourStep({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              Text(
                'What Mimir Can Do',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Track your EVE Online characters in real-time',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Feature cards
              Column(
                children: [
                  _buildFeatureCard(
                    context,
                    icon: Icons.dashboard_outlined,
                    color: theme.colorScheme.primary,
                    title: 'Dashboard',
                    description:
                        'Get a quick overview of your character\'s current status, '
                        'active skill training, and wallet balance all in one place.',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureCard(
                    context,
                    icon: Icons.psychology_outlined,
                    color: theme.colorScheme.secondary,
                    title: 'Skills',
                    description:
                        'Monitor your skill queue and see what\'s training. '
                        'Track completion times and plan your character progression.',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureCard(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    color: theme.colorScheme.tertiary,
                    title: 'Wallet',
                    description:
                        'View your ISK balance and recent transactions. '
                        'Keep track of your earnings and expenses across the galaxy.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
