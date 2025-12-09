import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../characters/data/character_providers.dart';
import '../../data/skill_catalogue_providers.dart';
import '../../data/skill_providers.dart';

/// Footer widget for the training queue sidebar showing key statistics.
///
/// Displays:
/// - Unallocated skill points
/// - Total training time in queue
/// - Total skill points in queue
///
/// Uses a dark background to visually separate from queue items.
class QueueFooter extends ConsumerWidget {
  const QueueFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d('SKILLS.UI', 'QueueFooter - building');
    final theme = Theme.of(context);
    final queueStats = ref.watch(queueStatsProvider);
    final unallocatedSpAsync = ref.watch(unallocatedSpProvider);

    // Format unallocated SP with commas
    final unallocatedSp = unallocatedSpAsync.when(
      data: (sp) => sp ?? 0,
      loading: () => 0,
      error: (_, __) => 0,
    );
    final formattedUnallocatedSp = NumberFormat('#,###').format(unallocatedSp);

    // Format total SP in queue
    final formattedTotalSp = NumberFormat('#,###').format(queueStats.totalSkillPoints);

    // Format training time
    final trainingTime = _formatDuration(queueStats.totalTrainingTime);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EveColors.surfaceDefault,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Divider with label
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'QUEUE STATS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Unallocated SP
          _buildStatRow(
            context,
            icon: Icons.stars_outlined,
            label: 'Unallocated SP',
            value: formattedUnallocatedSp,
          ),

          const SizedBox(height: 8),

          // Training time
          _buildStatRow(
            context,
            icon: Icons.schedule_outlined,
            label: 'Training Time',
            value: trainingTime,
          ),

          const SizedBox(height: 8),

          // Total SP in queue
          _buildStatRow(
            context,
            icon: Icons.fitness_center_outlined,
            label: 'SP in Queue',
            value: '$formattedTotalSp SP',
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Formats a duration for display in the footer.
  ///
  /// Examples:
  /// - 15 minutes → "15m"
  /// - 2 hours 30 minutes → "2h 30m"
  /// - 3 days 8 hours → "3d 8h 37m"
  /// - 162 days → "162d 9h 37m"
  String _formatDuration(Duration duration) {
    if (duration.isNegative || duration == Duration.zero) {
      return '0m';
    }

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    final parts = <String>[];

    if (days > 0) {
      parts.add('${days}d');
    }
    if (hours > 0) {
      parts.add('${hours}h');
    }
    if (minutes > 0 || parts.isEmpty) {
      parts.add('${minutes}m');
    }

    return parts.join(' ');
  }
}
