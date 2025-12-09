import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../characters/data/character_providers.dart';
import '../../data/skill_catalogue_providers.dart';
import '../../data/skill_repository.dart';
import '../../domain/skill_prerequisite_service.dart';
import 'skill_list_item.dart';

/// A 2-column panel displaying skills from the selected skill group.
///
/// Displays:
/// - Skills filtered by current filter mode
/// - 2-column grid layout
/// - Red background for skills character can't train
/// - Empty states (no group selected, no skills match filter)
/// - Loading/error states
///
/// Checks prerequisites for each skill to determine trainability.
class SkillListPanel extends ConsumerWidget {
  const SkillListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d('SKILLS.UI', 'SkillListPanel - building');
    final theme = Theme.of(context);
    final selectedGroupId = ref.watch(selectedSkillGroupProvider);
    final activeCharacter = ref.watch(activeCharacterProvider).value;
    final filterMode = ref.watch(skillFilterModeProvider);

    // No group selected
    if (selectedGroupId == null) {
      Log.d('SKILLS.UI', 'SkillListPanel - no group selected');
      return _buildEmptyState(
        context,
        icon: Icons.category_outlined,
        title: 'No Skill Group Selected',
        message: 'Select a skill group above to view skills',
      );
    }

    // Watch skills for selected group
    final skillsAsync = ref.watch(filteredSkillsByGroupProvider(selectedGroupId));

    return skillsAsync.when(
      data: (skills) {
        Log.d('SKILLS.UI', 'SkillListPanel - rendering ${skills.length} skills');

        if (skills.isEmpty) {
          // Different messages based on filter mode
          final emptyMessage = switch (filterMode) {
            SkillFilterMode.all => 'No skills found in this group',
            SkillFilterMode.mySkills => 'You haven\'t trained any skills in this group yet',
            SkillFilterMode.canTrain => 'No skills available to train in this group',
            SkillFilterMode.havePrereqs => 'No skills with met prerequisites in this group',
          };

          Log.d('SKILLS.UI', 'SkillListPanel - empty state: $emptyMessage');
          return _buildEmptyState(
            context,
            icon: Icons.school_outlined,
            title: 'No Skills',
            message: emptyMessage,
          );
        }

        // Build skill items with prerequisite checking
        return Container(
          decoration: BoxDecoration(
            color: EveColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3.5, // Wide items (width:height = 3.5:1)
            ),
            itemCount: skills.length,
            itemBuilder: (context, index) {
              final skill = skills[index];

              // For filter modes that already check prerequisites, we know canTrain is true
              if (filterMode == SkillFilterMode.canTrain ||
                  filterMode == SkillFilterMode.havePrereqs) {
                return SkillListItem(
                  skill: skill,
                  canTrain: true,
                );
              }

              // For "all" and "mySkills", check prerequisites individually
              if (activeCharacter == null || skill.trainedLevel >= 5) {
                // No character or already max level
                return SkillListItem(
                  skill: skill,
                  canTrain: skill.trainedLevel < 5,
                );
              }

              // Check if character can train this skill
              final prereqService = ref.read(skillPrerequisiteServiceProvider);
              return FutureBuilder<bool>(
                future: prereqService.canTrainSkill(
                  characterId: activeCharacter.characterId,
                  skillId: skill.skill.typeId,
                  targetLevel: skill.trainedLevel + 1,
                ),
                builder: (context, snapshot) {
                  final canTrain = snapshot.data ?? true; // Assume trainable while loading

                  return SkillListItem(
                    skill: skill,
                    canTrain: canTrain,
                  );
                },
              );
            },
          ),
        );
      },
      loading: () {
        Log.d('SKILLS.UI', 'SkillListPanel - loading');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: EveColors.photonBlue,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading skills...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
      error: (error, stack) {
        Log.e('SKILLS.UI', 'SkillListPanel - error loading skills', error, stack);
        return _buildErrorState(context, error);
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Center(
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
            'Failed to Load Skills',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
