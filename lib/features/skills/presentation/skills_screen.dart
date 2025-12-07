import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/space_background.dart';
import '../../characters/data/character_providers.dart';
import '../data/skill_providers.dart';
import '../data/skill_repository.dart';
import 'widgets/skill_queue_item.dart';

/// Screen displaying the character's skill training queue.
///
/// Shows all skills in the queue with training progress and
/// estimated completion times.
class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillQueue = ref.watch(skillQueueProvider);
    final activeCharacterAsync = ref.watch(activeCharacterProvider);

    return Scaffold(
      body: SpaceBackground(
        starDensity: 0.3,
        nebulaOpacity: 0.06,
        child: activeCharacterAsync.when(
          data: (activeCharacter) {
            if (activeCharacter == null) {
              return _buildNoCharacterState(context);
            }

            return skillQueue.when(
              data: (queue) {
                if (queue.isEmpty) {
                  return _buildEmptyState(
                      context, ref, activeCharacter.characterId);
                }

                return _buildSkillList(
                    context, ref, queue, activeCharacter.characterId);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(context, ref, error),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildCharacterErrorState(context, error),
        ),
      ),
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

  Widget _buildEmptyState(
      BuildContext context, WidgetRef ref, int characterId) {
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
    return RefreshIndicator(
      onRefresh: () => _refreshSkillQueue(ref, characterId),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: queue.length,
        itemBuilder: (context, index) {
          final entry = queue[index];
          return SkillQueueItemWidget(
            entry: entry,
            isCurrentlyTraining: entry.queuePosition == 0,
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    final theme = Theme.of(context);
    final activeCharacterAsync = ref.watch(activeCharacterProvider);

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
            activeCharacterAsync.whenData((character) {
              if (character != null) {
                return FilledButton.icon(
                  onPressed: () =>
                      _refreshSkillQueue(ref, character.characterId),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                );
              }
              return const SizedBox.shrink();
            }).value ?? const SizedBox.shrink(),
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
    final repository = ref.read(skillRepositoryProvider);
    await repository.refreshSkillQueue(characterId);
  }
}
