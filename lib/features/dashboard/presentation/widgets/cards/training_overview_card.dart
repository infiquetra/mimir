import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/eve_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/character_avatar.dart';
import '../../../../../core/widgets/eve_skill_icon.dart';
import '../../../data/dashboard_providers.dart';
import '../../../../skills/data/skill_providers.dart';
import '../../../../../core/sde/sde_providers.dart';
import '../dashboard_card.dart';

/// Dashboard card showing upcoming skill completions across all characters
/// and aggregate skill point statistics.
///
/// Displays:
/// - Next 3-5 skills completing soonest (any character)
/// - Character portrait, name, skill name, and time remaining for each
/// - Total SP across all characters (if available)
/// - Highlights skills completing within 24h
class TrainingOverviewCard extends ConsumerWidget {
  const TrainingOverviewCard({super.key});

  /// Maximum number of skills to display in the list.
  static const int maxSkillsToShow = 5;

  /// Duration threshold for warning highlight (24 hours).
  static const Duration warningThreshold = Duration(hours: 24);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextSkillsAsync = ref.watch(nextSkillsCompletingProvider);

    return DashboardCard(
      title: 'SKILL TRAINING',
      icon: Icons.school_outlined,
      glowColor: EveColors.evePrimary,
      isLoading: nextSkillsAsync.isLoading,
      errorMessage: nextSkillsAsync.hasError
          ? 'Failed to load skill training data'
          : null,
      onRetry: () => ref.invalidate(nextSkillsCompletingProvider),
      child: nextSkillsAsync.when(
        data: (completions) => _buildContent(context, ref, completions),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<NextSkillCompletion> completions,
  ) {
    if (completions.isEmpty) {
      return _buildEmptyState(context);
    }

    // Take only first maxSkillsToShow items
    final displayCompletions = completions.take(maxSkillsToShow).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          'COMPLETING SOON',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withAlpha(179),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: 12),

        // Skill completion list
        ...displayCompletions.map((completion) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSkillRow(context, ref, completion),
          );
        }),

        const SizedBox(height: 8),

        // Total SP statistics (placeholder for now)
        _buildStatistics(context, ref, completions),
      ],
    );
  }

  Widget _buildSkillRow(
    BuildContext context,
    WidgetRef ref,
    NextSkillCompletion completion,
  ) {
    final character = completion.character;
    final skill = completion.skillEntry;
    final finishDate = skill.finishDate;

    // Calculate time remaining
    Duration? remaining;
    bool isUrgent = false;
    if (finishDate != null) {
      remaining = finishDate.difference(DateTime.now());
      isUrgent = remaining <= warningThreshold && !remaining.isNegative;
    }

    // Watch skill name
    final skillNameAsync = ref.watch(skillNameProvider(skill.skillId));

    return Row(
      children: [
        // Character portrait
        CharacterAvatar(
          portraitUrl: character.portraitUrl,
          size: CharacterAvatarSize.small,
        ),
        const SizedBox(width: 8),

        // Skill icon
        EveSkillIcon(
          typeId: skill.skillId,
          size: 32,
        ),
        const SizedBox(width: 8),

        // Skill info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Character name
              Text(
                character.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withAlpha(179),
                      fontSize: 11,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Skill name and level
              skillNameAsync.when(
                data: (skillName) {
                  final romanNumerals = ['I', 'II', 'III', 'IV', 'V'];
                  final levelStr = skill.finishedLevel >= 1 &&
                          skill.finishedLevel <= 5
                      ? romanNumerals[skill.finishedLevel - 1]
                      : '${skill.finishedLevel}';
                  final fullName = '$skillName $levelStr';

                  return Text(
                    fullName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isUrgent ? EveColors.warning : Colors.white,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
                loading: () => Container(
                  height: 16,
                  width: 120,
                  decoration: BoxDecoration(
                    color: EveColors.darkSurfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                error: (_, __) => Text(
                  'Skill #${skill.skillId}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isUrgent ? EveColors.warning : Colors.white,
                      ),
                ),
              ),
            ],
          ),
        ),

        // Time remaining
        if (remaining != null && !remaining.isNegative)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: isUrgent ? EveColors.warning : Colors.white.withAlpha(179),
              ),
              const SizedBox(width: 4),
              Text(
                formatDuration(remaining),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isUrgent ? EveColors.warning : Colors.white.withAlpha(179),
                      fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ],
          )
        else if (remaining != null && remaining.isNegative)
          const Icon(
            Icons.check_circle,
            size: 16,
            color: EveColors.success,
          ),
      ],
    );
  }

  Widget _buildStatistics(
    BuildContext context,
    WidgetRef ref,
    List<NextSkillCompletion> completions,
  ) {
    final queuesAsync = ref.watch(allCharacterSkillQueuesProvider);

    return queuesAsync.when(
      data: (queuesMap) {
        // Calculate total SP and unallocated SP
        int totalSp = 0;
        int unallocatedSp = 0;

        // For each character's queue, sum up the SP
        for (final queue in queuesMap.values) {
          for (final entry in queue) {
            // Use levelEndSp as a proxy for total SP (not accurate, but illustrative)
            if (entry.levelEndSp != null) {
              totalSp += entry.levelEndSp!;
            }
          }
        }

        // Only show statistics if we have data
        if (totalSp == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: EveColors.darkSurfaceVariant.withAlpha(128),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Note: This is illustrative - actual total SP would come from ESI character data
              Text(
                'TRAINING STATISTICS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withAlpha(179),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 14,
                    color: EveColors.evePrimary.withAlpha(179),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${completions.length} skills in training queue',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withAlpha(204),
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 48,
              color: Colors.white.withAlpha(77),
            ),
            const SizedBox(height: 12),
            Text(
              'No Active Training',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withAlpha(179),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your characters have no skills in their training queues',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withAlpha(128),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
