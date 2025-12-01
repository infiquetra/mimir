import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/eve_colors.dart';
import '../../../../skills/data/skill_providers.dart';
import '../../../../skills/presentation/widgets/skill_queue_item.dart';
import '../../../data/character_providers.dart';

/// Skills sub-tab showing skill queue and training information.
///
/// Displays:
/// - Currently training skill
/// - Full skill queue
/// - Queue completion time
class SkillsSubTab extends ConsumerWidget {
  const SkillsSubTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider);

    return activeCharacter.when(
      data: (character) {
        if (character == null) {
          return _buildNoCharacterState(context);
        }
        return _buildSkillsView(context, ref);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading character: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  Widget _buildNoCharacterState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No Character Selected',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsView(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final skillQueue = ref.watch(skillQueueProvider);
    final currentTraining = ref.watch(currentTrainingProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Currently training card
          Card(
            elevation: 0,
            color: EveColors.darkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: EveColors.evePrimary.withAlpha(51),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 20,
                        color: EveColors.evePrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Currently Training',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: EveColors.evePrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (currentTraining == null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.pause_circle_outline,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No skill currently training',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SkillQueueItemWidget(
                      entry: currentTraining,
                      isCurrentlyTraining: true,
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Skill queue card
          skillQueue.when(
            data: (skills) {
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.queue_outlined,
                            size: 20,
                            color: EveColors.evePrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Skill Queue',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: EveColors.evePrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: EveColors.evePrimary.withAlpha(51),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${skills.length}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: EveColors.evePrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (skills.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 48,
                                  color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Skill queue is empty',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          children: skills.map((skill) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SkillQueueItemWidget(
                                entry: skill,
                                isCurrentlyTraining: false,
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Card(
              elevation: 0,
              color: EveColors.darkSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: EveColors.evePrimary.withAlpha(51),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load skill queue',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
