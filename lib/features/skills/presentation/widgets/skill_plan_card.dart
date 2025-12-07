import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/skill_plan_providers.dart';

/// Card displaying a skill plan with progress and time estimates.
///
/// Shows:
/// - Plan name and description
/// - Progress: X/Y skills trained
/// - Progress bar with percentage
/// - Training time estimate
/// - Edit/Delete action buttons
class SkillPlanCard extends ConsumerWidget {
  final SkillPlan plan;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const SkillPlanCard({
    super.key,
    required this.plan,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progressAsync = ref.watch(skillPlanProgressProvider(plan.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with name and actions
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (plan.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            plan.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          iconSize: 20,
                          onPressed: onEdit,
                          tooltip: 'Edit Plan',
                        ),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          iconSize: 20,
                          onPressed: onDelete,
                          tooltip: 'Delete Plan',
                          color: theme.colorScheme.error,
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress information
              progressAsync.when(
                data: (progress) => _buildProgressContent(context, progress),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => Text(
                  'Failed to load progress',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressContent(BuildContext context, SkillPlanProgress progress) {
    final theme = Theme.of(context);
    final progressPercent = progress.percentComplete / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats row
        Row(
          children: [
            // Skills progress
            Expanded(
              child: Text(
                '${progress.trainedSkills}/${progress.totalSkills} skills trained',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Training time
            if (progress.estimatedTimeSeconds > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      progress.estimatedTimeFormatted,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressPercent,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              progressPercent >= 1.0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Percentage text
        Text(
          '${progress.percentComplete.toStringAsFixed(1)}% complete',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        // SP remaining (if implemented)
        if (progress.totalSpRequired > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${formatSpCompact(progress.totalSpRequired)} remaining',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
