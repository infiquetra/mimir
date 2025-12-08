import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/widgets/data_row.dart';
import '../../../characters/data/character_providers.dart';
import '../../data/skill_providers.dart';
import '../../data/skill_repository.dart';
import 'skill_queue_item.dart';

/// Panel displaying the skill training queue.
///
/// Shows:
/// - All skills in the queue with progress bars
/// - Currently training skill highlighted
/// - Estimated completion times
/// - Empty state when queue is empty
/// - Pull-to-refresh support
class TrainingQueuePanel extends ConsumerWidget {
  const TrainingQueuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d('SKILLS', 'TrainingQueuePanel.build - START');
    final skillQueue = ref.watch(skillQueueProvider);
    final activeCharacterAsync = ref.watch(activeCharacterProvider);

    return activeCharacterAsync.when(
      data: (activeCharacter) {
        if (activeCharacter == null) {
          return _buildNoCharacterState(context);
        }

        return skillQueue.when(
          data: (queue) {
            Log.d('SKILLS', 'TrainingQueuePanel - queue has ${queue.length} items');
            if (queue.isEmpty) {
              return _buildEmptyState(context, ref, activeCharacter.characterId);
            }

            return _buildSkillList(
              context,
              ref,
              queue,
              activeCharacter.characterId,
            );
          },
          loading: () {
            Log.d('SKILLS', 'TrainingQueuePanel - loading');
            return const Center(child: CircularProgressIndicator());
          },
          error: (error, stack) {
            Log.e('SKILLS', 'TrainingQueuePanel - error', error, stack);
            return _buildErrorState(context, ref, activeCharacter.characterId, error);
          },
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
              'Add a character to view your skill queue.',
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

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, int characterId) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () => _refreshSkillQueue(ref, characterId),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Skills Training',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your skill queue is empty.\nAdd skills to train in EVE Online.',
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
        ],
      ),
    );
  }

  Widget _buildSkillList(
    BuildContext context,
    WidgetRef ref,
    List queue,
    int characterId,
  ) {
    Log.d('SKILLS', 'TrainingQueuePanel._buildSkillList - ${queue.length} skills');
    return RefreshIndicator(
      onRefresh: () => _refreshSkillQueue(ref, characterId),
      child: Column(
        children: [
          // Table header
          const DataHeaderRow(
            columns: ['#', 'Skill', 'Level', 'Time'],
            flexValues: [1, 5, 1, 2],
          ),

          // Skill queue list
          Expanded(
            child: ListView.builder(
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final entry = queue[index];
                return SkillQueueItemWidget(
                  entry: entry,
                  isCurrentlyTraining: entry.queuePosition == 0,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    WidgetRef ref,
    int characterId,
    Object error,
  ) {
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
              'Failed to Load Skills',
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
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _refreshSkillQueue(ref, characterId),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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

  Future<void> _refreshSkillQueue(WidgetRef ref, int characterId) async {
    Log.i('SKILLS', 'TrainingQueuePanel._refreshSkillQueue - refreshing for character $characterId');
    final repository = ref.read(skillRepositoryProvider);
    await repository.refreshSkillQueue(characterId);
  }
}
