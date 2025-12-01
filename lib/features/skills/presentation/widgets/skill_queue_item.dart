import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sde/sde_providers.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../../../core/widgets/eve_skill_icon.dart';

/// Widget displaying a single skill queue entry.
///
/// Shows the skill icon, name from SDE, target level, and training time remaining.
/// Falls back to "Skill #`<id>`" if the SDE data is not available.
class SkillQueueItemWidget extends ConsumerWidget {
  const SkillQueueItemWidget({
    required this.entry,
    this.isCurrentlyTraining = false,
    super.key,
  });

  final SkillQueueEntry entry;
  final bool isCurrentlyTraining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final skillNameAsync = ref.watch(skillNameProvider(entry.skillId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: EveCard(
        glowColor: isCurrentlyTraining ? EveColors.evePrimary : null,
        glowIntensity: isCurrentlyTraining ? 0.4 : 0.0,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Skill icon from EVE Image API.
            _buildSkillIcon(),
            const SizedBox(width: 12),

            // Skill info.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skill name from SDE.
                  skillNameAsync.when(
                    data: (skillName) => Text(
                      skillName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isCurrentlyTraining
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrentlyTraining
                            ? EveColors.evePrimary
                            : Colors.white,
                      ),
                    ),
                    loading: () => Container(
                      height: 20,
                      width: 120,
                      decoration: BoxDecoration(
                        color: EveColors.darkSurfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    error: (_, __) => Text(
                      'Skill #${entry.skillId}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isCurrentlyTraining
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrentlyTraining
                            ? EveColors.evePrimary
                            : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Target level with Roman numerals.
                  Row(
                    children: [
                      Text(
                        'Level ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withAlpha(179),
                        ),
                      ),
                      _buildLevelIndicator(entry.finishedLevel),
                    ],
                  ),

                  // Training time remaining.
                  if (entry.finishDate != null) ...[
                    const SizedBox(height: 8),
                    _buildTimeRemaining(theme),
                  ],

                  // Training progress bar for currently training skill.
                  if (isCurrentlyTraining && entry.startDate != null && entry.finishDate != null)
                    _buildProgressBar(),
                ],
              ),
            ),

            // Queue position badge.
            _buildQueueBadge(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillIcon() {
    return EveSkillIcon(
      typeId: entry.skillId,
      size: 48,
      showBorder: isCurrentlyTraining,
      borderColor: isCurrentlyTraining ? EveColors.evePrimary : null,
    );
  }

  Widget _buildLevelIndicator(int level) {
    const romanNumerals = ['I', 'II', 'III', 'IV', 'V'];
    final numeral = level >= 1 && level <= 5 ? romanNumerals[level - 1] : '$level';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final isActive = index < level;
        return Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: isActive
                ? EveColors.evePrimary.withAlpha(204)
                : EveColors.darkSurfaceVariant,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: isActive
                  ? EveColors.evePrimary
                  : Colors.white.withAlpha(26),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              index == level - 1 ? numeral : '',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.transparent,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildQueueBadge(ThemeData theme) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrentlyTraining
            ? EveColors.evePrimary.withAlpha(51)
            : EveColors.darkSurfaceVariant,
        border: Border.all(
          color: isCurrentlyTraining
              ? EveColors.evePrimary
              : Colors.white.withAlpha(51),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          '${entry.queuePosition + 1}',
          style: TextStyle(
            fontSize: 12,
            color: isCurrentlyTraining
                ? EveColors.evePrimary
                : Colors.white.withAlpha(179),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final startDate = entry.startDate!;
    final finishDate = entry.finishDate!;
    final now = DateTime.now();

    final totalDuration = finishDate.difference(startDate).inSeconds;
    final elapsedDuration = now.difference(startDate).inSeconds;
    final progress = (elapsedDuration / totalDuration).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: EveColors.darkSurfaceVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(EveColors.evePrimary),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% complete',
            style: TextStyle(
              fontSize: 11,
              color: EveColors.evePrimary.withAlpha(179),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRemaining(ThemeData theme) {
    final finishDate = entry.finishDate!;
    final now = DateTime.now();
    final remaining = finishDate.difference(now);

    // If already finished, show completed.
    if (remaining.isNegative) {
      return const Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: EveColors.success,
          ),
          SizedBox(width: 4),
          Text(
            'Completed',
            style: TextStyle(
              fontSize: 13,
              color: EveColors.success,
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
          color: isCurrentlyTraining
              ? EveColors.evePrimary
              : Colors.white.withAlpha(128),
        ),
        const SizedBox(width: 4),
        Text(
          formatDuration(remaining),
          style: TextStyle(
            fontSize: 13,
            color: isCurrentlyTraining
                ? EveColors.evePrimary
                : Colors.white.withAlpha(179),
            fontWeight: isCurrentlyTraining ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
