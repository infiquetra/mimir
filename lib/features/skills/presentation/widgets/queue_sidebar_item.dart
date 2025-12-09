import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../data/skill_providers.dart';

/// A compact queue entry item for the training queue sidebar.
///
/// Displays:
/// - Skill name with Roman numeral level (e.g., "Mechanics V")
/// - Time remaining to completion
/// - Progress bar showing completion percentage
/// - Highlighted background for currently training skill
///
/// Optimized for narrow width (280px sidebar).
class QueueSidebarItem extends ConsumerWidget {
  const QueueSidebarItem({
    super.key,
    required this.entry,
  });

  final SkillQueueEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d('SKILLS.UI', 'QueueSidebarItem - rendering skill ${entry.skillId}');
    final theme = Theme.of(context);
    final skillNameAsync = ref.watch(skillNameProvider(entry.skillId));
    final isCurrentlyTraining = entry.queuePosition == 0;

    // Calculate time remaining and progress
    final now = DateTime.now();
    final timeRemaining = entry.finishDate?.difference(now);
    final totalTime = entry.finishDate != null && entry.startDate != null
        ? entry.finishDate!.difference(entry.startDate!)
        : null;
    final progress = timeRemaining != null && totalTime != null && totalTime.inSeconds > 0
        ? 1.0 - (timeRemaining.inSeconds / totalTime.inSeconds)
        : 0.0;

    // Background color for currently training
    final backgroundColor = isCurrentlyTraining
        ? EveColors.photonBlue.withOpacity(0.15)
        : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCurrentlyTraining
              ? EveColors.photonBlue.withOpacity(0.5)
              : theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Skill name + level
          skillNameAsync.when(
            data: (skillName) {
              final levelRoman = _toRomanNumeral(entry.finishedLevel);
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      '$skillName $levelRoman',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isCurrentlyTraining ? FontWeight.w600 : FontWeight.normal,
                        color: isCurrentlyTraining
                            ? EveColors.photonBlue
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCurrentlyTraining) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.trending_up,
                      size: 12,
                      color: EveColors.photonBlue,
                    ),
                  ],
                ],
              );
            },
            loading: () => Text(
              'Loading...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            error: (_, __) => Text(
              'Skill #${entry.skillId} ${_toRomanNumeral(entry.finishedLevel)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 6),

          // Time remaining
          if (timeRemaining != null && !timeRemaining.isNegative) ...[
            Text(
              _formatDuration(timeRemaining),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCurrentlyTraining
                      ? EveColors.photonBlue
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ] else ...[
            Text(
              'Paused',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Converts a skill level (1-5) to Roman numerals.
  String _toRomanNumeral(int level) {
    return switch (level) {
      1 => 'I',
      2 => 'II',
      3 => 'III',
      4 => 'IV',
      5 => 'V',
      _ => level.toString(),
    };
  }

  /// Formats a duration for display in the queue.
  ///
  /// Examples:
  /// - 15 minutes → "15m"
  /// - 2 hours 30 minutes → "2h 30m"
  /// - 3 days 8 hours → "3d 8h"
  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return hours > 0 ? '${days}d ${hours}h' : '${days}d';
    } else if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    } else {
      return '${minutes}m';
    }
  }
}
