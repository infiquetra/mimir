import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../characters/data/character_providers.dart';

/// Panel displaying the skill catalogue organized by groups.
///
/// Shows:
/// - All skill groups in 3-column responsive layout
/// - Groups are collapsible to show individual skills
/// - Progress bars showing trained vs total skills per group
/// - Individual skills with level indicators
///
/// TODO: Full implementation with skill groups and expansion logic.
class SkillCataloguePanel extends ConsumerStatefulWidget {
  const SkillCataloguePanel({super.key});

  @override
  ConsumerState<SkillCataloguePanel> createState() => _SkillCataloguePanelState();
}

class _SkillCataloguePanelState extends ConsumerState<SkillCataloguePanel> {
  // Track which groups are expanded
  final Set<int> _expandedGroups = {};

  @override
  Widget build(BuildContext context) {
    Log.d('SKILLS', 'SkillCataloguePanel.build - START');
    final activeCharacterAsync = ref.watch(activeCharacterProvider);
    final theme = Theme.of(context);

    return activeCharacterAsync.when(
      data: (activeCharacter) {
        if (activeCharacter == null) {
          return _buildNoCharacterState(context);
        }

        // TODO: Implement full catalogue with skill groups
        // For now, show placeholder
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_books_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Skill Catalogue',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Full skill catalogue with groups coming soon.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildCharacterErrorState(context, error),
    );
  }

  Widget _buildNoCharacterState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Character Selected',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a character to view your skills.',
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

  Widget _buildCharacterErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Character',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
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
