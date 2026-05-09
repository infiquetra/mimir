import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../../../core/widgets/eve_type_icon.dart';
import '../../../../core/database/app_database.dart';
import '../../data/industry_providers.dart';

/// Panel displaying the character's industry jobs.
class IndustryJobsPanel extends ConsumerWidget {
  const IndustryJobsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(characterIndustryJobsProvider);

    return jobsAsync.when(
      data: (jobs) {
        if (jobs.isEmpty) {
          return const EmptyState(
            icon: Icons.factory,
            heading: 'No Industry Jobs',
            description:
                'You do not have any active or recently completed industry jobs.',
          );
        }

        return ListView.builder(
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            return _JobListItem(job: job);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => EmptyState(
        icon: Icons.error_outline,
        heading: 'Failed to Load Jobs',
        description: err.toString(),
        action: ElevatedButton(
          onPressed: () => ref.refresh(characterIndustryJobsProvider),
          child: const Text('Retry'),
        ),
      ),
    );
  }
}

class _JobListItem extends ConsumerWidget {
  final IndustryJob job;

  const _JobListItem({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final isCompleted = job.endDate.isBefore(now) || job.status == 'delivered';
    final progress = isCompleted
        ? 1.0
        : now.difference(job.startDate).inSeconds / job.timeInSeconds;

    final clampedProgress = progress.clamp(0.0, 1.0);

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (job.status) {
      case 'active':
        if (isCompleted) {
          statusColor = EveColors.success;
          statusIcon = Icons.check_circle;
          statusText = 'Ready for Delivery';
        } else {
          statusColor = Colors.blue.shade400;
          statusIcon = Icons.sync;
          statusText = 'Active';
        }
        break;
      case 'delivered':
        statusColor = EveColors.textSecondary;
        statusIcon = Icons.inventory;
        statusText = 'Delivered';
        break;
      case 'paused':
        statusColor = EveColors.warning;
        statusIcon = Icons.pause_circle;
        statusText = 'Paused';
        break;
      case 'cancelled':
      case 'reverted':
      default:
        statusColor = EveColors.error;
        statusIcon = Icons.cancel;
        statusText = 'Cancelled';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: EveCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  // Activity icon (simplified for MVP: just showing output product icon)
                  EveTypeIcon(
                    typeId: job.productTypeId ?? job.blueprintTypeId,
                    size: 40,
                  ),
                  const SizedBox(width: 16),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          'Job #${job.jobId} - Type ${job.productTypeId ?? job.blueprintTypeId}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Status and times
                        Row(
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: statusColor),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Runs: ${job.runs}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const Spacer(),
                            if (!isCompleted && job.status == 'active')
                              Text(
                                formatDuration(job.endDate.difference(now)),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.blue.shade200,
                                ),
                              )
                            else if (isCompleted)
                              Text(
                                DateFormat.yMMMd().format(job.endDate),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: EveColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Progress Bar
              if (job.status == 'active' && !isCompleted) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: clampedProgress,
                  backgroundColor:
                      EveColors.backgroundDeep.withValues(alpha: 0.5),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
                  minHeight: 4,
                ),
              ] else if (job.status == 'active' && isCompleted) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: 1.0,
                  backgroundColor:
                      EveColors.backgroundDeep.withValues(alpha: 0.5),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(EveColors.success),
                  minHeight: 4,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
