import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../data/skill_catalogue_providers.dart';
import '../../data/skill_group_icons.dart';

/// A compact row representing a skill group in the 3-column grid.
///
/// Displays (EVE Online style):
/// - Small icon (24px) on left
/// - Group name text OVER progress bar (teal background)
/// - Skill count badge on right (X/Y or just count)
///
/// Very compact (~36px height), no card borders.
/// Progress bar shows % of skills trained in group.
class SkillGroupTile extends ConsumerWidget {
  const SkillGroupTile({
    super.key,
    required this.group,
    required this.isSelected,
    this.onTap,
  });

  final SkillGroupWithProgress group;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trainedPercent =
        group.totalCount > 0 ? group.trainedCount / group.totalCount : 0.0;

    final icon = SkillGroupIcons.getIcon(group.group.groupName);

    return InkWell(
      onTap: () {
        Log.d('SKILLS.UI', 'SkillGroupTile - selected group ${group.group.groupId}');
        onTap?.call();
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: isSelected
              ? EveColors.surfaceElevated.withOpacity(0.5)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Icon (24px)
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? EveColors.photonBlue
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),

            // Group name with progress bar behind it
            Expanded(
              child: Stack(
                children: [
                  // Progress bar (bottom layer)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: trainedPercent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? EveColors.photonBlue.withOpacity(0.3)
                              : EveColors.photonCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),

                  // Group name text (top layer)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      group.group.groupName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? EveColors.photonBlue
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Count badge
            Text(
              '${group.trainedCount}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
