import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sde/sde_providers.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/theme/eve_spacing.dart';
import '../../../../core/theme/eve_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/eve_skill_icon.dart';

/// Compact skill queue item (28px height).
///
/// Shows skill icon, name, level, and time remaining in a single row.
/// Currently training skill is highlighted with Photon Blue.
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
    final skillNameAsync = ref.watch(skillNameProvider(entry.skillId));
    final romanNumerals = ['I', 'II', 'III', 'IV', 'V'];
    final levelRoman = entry.finishedLevel >= 1 && entry.finishedLevel <= 5
        ? romanNumerals[entry.finishedLevel - 1]
        : '${entry.finishedLevel}';

    return Container(
      height: EveSpacing.rowHeight,
      padding: EdgeInsets.symmetric(
        horizontal: EveSpacing.lg,
        vertical: EveSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isCurrentlyTraining
            ? EveColors.photonBlue.withAlpha(26) // 10% opacity
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: EveColors.divider,
            width: 0.5,
          ),
          left: isCurrentlyTraining
              ? BorderSide(
                  color: EveColors.photonBlue,
                  width: 3,
                )
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          // Compact skill icon (20px inline)
          EveSkillIcon(
            typeId: entry.skillId,
            size: EveSpacing.iconSm,
          ),
          SizedBox(width: EveSpacing.md),

          // Queue position
          SizedBox(
            width: 20,
            child: Text(
              '${entry.queuePosition + 1}.',
              style: EveTypography.labelSmall(
                color: isCurrentlyTraining
                    ? EveColors.photonBlue
                    : EveColors.textTertiary,
              ),
            ),
          ),
          SizedBox(width: EveSpacing.sm),

          // Skill name
          Expanded(
            flex: 3,
            child: skillNameAsync.when(
              data: (skillName) => Text(
                skillName,
                style: EveTypography.bodySmall(
                  color: isCurrentlyTraining
                      ? EveColors.photonBlue
                      : EveColors.textPrimary,
                ).copyWith(
                  fontWeight:
                      isCurrentlyTraining ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              loading: () => Container(
                height: 12,
                width: 80,
                decoration: BoxDecoration(
                  color: EveColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(EveSpacing.xs),
                ),
              ),
              error: (_, __) => Text(
                'Skill #${entry.skillId}',
                style: EveTypography.bodySmall(
                  color: EveColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(width: EveSpacing.md),

          // Target level (compact)
          SizedBox(
            width: 40,
            child: Text(
              '→ $levelRoman',
              style: EveTypography.labelSmall(
                color: EveColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: EveSpacing.md),

          // Time remaining (compact)
          if (entry.finishDate != null)
            SizedBox(
              width: 70,
              child: _buildCompactTimeRemaining(),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactTimeRemaining() {
    final finishDate = entry.finishDate!;
    final now = DateTime.now();
    final remaining = finishDate.difference(now);

    // If already finished, show checkmark
    if (remaining.isNegative) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: EveSpacing.iconXs,
            color: EveColors.success,
          ),
          SizedBox(width: EveSpacing.xs),
          Text(
            'Done',
            style: EveTypography.labelSmall(
              color: EveColors.success,
            ),
          ),
        ],
      );
    }

    return Text(
      formatDuration(remaining),
      style: EveTypography.dataSmall(
        color: isCurrentlyTraining
            ? EveColors.photonBlue
            : EveColors.textSecondary,
      ),
      textAlign: TextAlign.right,
    );
  }
}
