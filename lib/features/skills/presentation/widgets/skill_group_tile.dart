import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/eve_skill_icon.dart';
import '../../data/skill_catalogue_providers.dart';

/// A compact tile representing a skill group in the 3-column grid.
///
/// Displays:
/// - Representative skill icon (first skill in group)
/// - Group name
/// - Progress bar showing trained skills
/// - Count badge (X/Y trained)
///
/// Can be selected to show skills in that group in the lower panel.
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
    final representativeSkillAsync =
        ref.watch(groupRepresentativeSkillProvider(group.group.groupId));

    final trainedPercent =
        group.totalCount > 0 ? group.trainedCount / group.totalCount : 0.0;

    return InkWell(
      onTap: () {
        Log.d('SKILLS.UI', 'SkillGroupTile - selected group ${group.group.groupId}');
        onTap?.call();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? EveColors.photonBlue
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? EveColors.photonBlue.withOpacity(0.1)
              : EveColors.surfaceDefault,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: Icon + Name
            Row(
              children: [
                // Representative skill icon
                representativeSkillAsync.when(
                  data: (typeId) => EveSkillIcon(
                    typeId: typeId ?? group.group.groupId, // Fallback to groupId
                    size: 32,
                  ),
                  loading: () => Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.folder_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  error: (_, __) => Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 20,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Group name
                Expanded(
                  child: Text(
                    group.group.groupName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? EveColors.photonBlue
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${group.trainedCount}/${group.totalCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: trainedPercent,
                minHeight: 4,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isSelected ? EveColors.photonBlue : theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
