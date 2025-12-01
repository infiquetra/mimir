import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import '../tabs/character_sub_tabs/attributes_sub_tab.dart';
import '../tabs/character_sub_tabs/jump_clones_sub_tab.dart';
import '../tabs/interactions_sub_tabs/standings_sub_tab.dart';

/// Multi-column card grid for character information.
///
/// Displays character data in a responsive grid layout with cards for:
/// - Attributes
/// - Jump Clones
/// - Standings
/// - Employment History (placeholder)
///
/// Uses 2 columns on wide screens (>=600px), 1 column on narrow screens.
class CharacterContentGrid extends ConsumerWidget {
  const CharacterContentGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use MediaQuery for reliable width detection
    // Right panel is ~60% of screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth * 0.6;
    final useWideLayout = panelWidth >= 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: useWideLayout
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column
                Expanded(
                  child: Column(
                    children: [
                      _AttributesCard(),
                      const SizedBox(height: 16),
                      _StandingsCard(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right column
                Expanded(
                  child: Column(
                    children: [
                      _JumpClonesCard(),
                      const SizedBox(height: 16),
                      _EmploymentHistoryCard(),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _AttributesCard(),
                const SizedBox(height: 16),
                _JumpClonesCard(),
                const SizedBox(height: 16),
                _StandingsCard(),
                const SizedBox(height: 16),
                _EmploymentHistoryCard(),
              ],
            ),
    );
  }
}

/// Attributes card wrapper.
class _AttributesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // No fixed height - let content determine size
    return const AttributesSubTab();
  }
}

/// Jump Clones card wrapper.
class _JumpClonesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // No fixed height - let content determine size
    return const JumpClonesSubTab();
  }
}

/// Standings card wrapper.
class _StandingsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // No fixed height - let content determine size
    return const StandingsSubTab();
  }
}

/// Employment History placeholder card.
class _EmploymentHistoryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: EveColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: EveColors.evePrimary.withAlpha(51),
          width: 1,
        ),
      ),
      // Removed fixed height - content determines size
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_outlined,
              size: 64,
              color: EveColors.evePrimary.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              'Employment History',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: EveColors.evePrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Corporation and alliance history coming soon',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
