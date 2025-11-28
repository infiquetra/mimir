import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';

/// Widget displaying a single skill queue entry.
///
/// Shows the skill ID (name will come from SDE later), target level,
/// and training time remaining.
class SkillQueueItemWidget extends StatelessWidget {
  const SkillQueueItemWidget({
    required this.entry,
    this.isCurrentlyTraining = false,
    super.key,
  });

  final SkillQueueEntry entry;
  final bool isCurrentlyTraining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Queue position indicator.
            _buildPositionIndicator(theme),
            const SizedBox(width: 16),

            // Skill info.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skill name (ID for now, SDE will provide names later).
                  Text(
                    'Skill #${entry.skillId}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight:
                          isCurrentlyTraining ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Target level.
                  Text(
                    'Training to Level ${entry.finishedLevel}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  // Training time remaining.
                  if (entry.finishDate != null) ...[
                    const SizedBox(height: 8),
                    _buildTimeRemaining(theme),
                  ],
                ],
              ),
            ),

            // Training indicator.
            if (isCurrentlyTraining)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow,
                      size: 16,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Training',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
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

  Widget _buildPositionIndicator(ThemeData theme) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrentlyTraining
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: Text(
          '${entry.queuePosition + 1}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: isCurrentlyTraining
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRemaining(ThemeData theme) {
    final finishDate = entry.finishDate!;
    final now = DateTime.now();
    final remaining = finishDate.difference(now);

    // If already finished, show completed.
    if (remaining.isNegative) {
      return Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            'Completed',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          Icons.schedule,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          formatDuration(remaining),
          style: theme.textTheme.bodySmall?.copyWith(
            color: isCurrentlyTraining
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isCurrentlyTraining ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
