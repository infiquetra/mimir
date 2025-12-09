import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../characters/data/character_providers.dart';
import '../../data/skill_providers.dart';
import 'queue_footer.dart';
import 'queue_sidebar_item.dart';

/// Fixed-width sidebar displaying the training queue and stats.
///
/// Displays:
/// - Header with queue size (X/150)
/// - Scrollable list of queue items
/// - Footer with unallocated SP, training time, SP in queue
/// - Empty state when no queue
/// - No character state
///
/// Fixed width of 280px to match EVE Online's design.
class TrainingQueueSidebar extends ConsumerWidget {
  const TrainingQueueSidebar({super.key});

  static const double width = 280.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d('SKILLS.UI', 'TrainingQueueSidebar - building');
    final theme = Theme.of(context);
    final activeCharacter = ref.watch(activeCharacterProvider).value;

    // No character selected
    if (activeCharacter == null) {
      return SizedBox(
        width: width,
        child: Container(
          decoration: BoxDecoration(
            color: EveColors.surfaceElevated,
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Character',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a character to view their training queue',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
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

    final queueAsync = ref.watch(skillQueueProvider);

    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: EveColors.surfaceElevated,
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: queueAsync.when(
          data: (queue) {
            Log.d('SKILLS.UI', 'TrainingQueueSidebar - rendering ${queue.length} queue items');

            return Column(
              children: [
                // Header
                _buildHeader(context, queue.length),

                // Queue items or empty state
                if (queue.isEmpty)
                  Expanded(child: _buildEmptyState(context))
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final entry = queue[index];
                        return QueueSidebarItem(entry: entry);
                      },
                    ),
                  ),

                // Footer
                const QueueFooter(),
              ],
            );
          },
          loading: () {
            Log.d('SKILLS.UI', 'TrainingQueueSidebar - loading');
            return Column(
              children: [
                _buildHeader(context, 0),
                Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: EveColors.photonBlue,
                    ),
                  ),
                ),
              ],
            );
          },
          error: (error, stack) {
            Log.e('SKILLS.UI', 'TrainingQueueSidebar - error loading queue', error, stack);
            return Column(
              children: [
                _buildHeader(context, 0),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to Load Queue',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
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
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int queueSize) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EveColors.surfaceDefault,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.list_alt,
            size: 18,
            color: EveColors.photonBlue,
          ),
          const SizedBox(width: 8),
          Text(
            'TRAINING QUEUE',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$queueSize/50',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Queue Empty',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No skills currently training.\nAdd skills to your queue to begin.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
