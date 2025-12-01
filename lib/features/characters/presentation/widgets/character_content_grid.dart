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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine column count based on available width
          final useWideLayout = constraints.maxWidth >= 600;

          if (useWideLayout) {
            // 2-column layout for wide screens
            return Row(
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
            );
          } else {
            // Single column layout for narrow screens
            return Column(
              children: [
                _AttributesCard(),
                const SizedBox(height: 16),
                _JumpClonesCard(),
                const SizedBox(height: 16),
                _StandingsCard(),
                const SizedBox(height: 16),
                _EmploymentHistoryCard(),
              ],
            );
          }
        },
      ),
    );
  }
}

/// Attributes card wrapper.
class _AttributesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 600, // Fixed height for consistent card sizing
      child: AttributesSubTab(),
    );
  }
}

/// Jump Clones card wrapper.
class _JumpClonesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 600, // Fixed height for consistent card sizing
      child: JumpClonesSubTab(),
    );
  }
}

/// Standings card wrapper.
class _StandingsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 400, // Shorter height for standings
      child: StandingsSubTab(),
    );
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
      child: SizedBox(
        height: 300,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
        ),
      ),
    );
  }
}
