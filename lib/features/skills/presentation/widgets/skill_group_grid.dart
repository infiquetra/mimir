import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../data/skill_catalogue_providers.dart';
import 'skill_group_tile.dart';

/// A 3-column grid displaying all skill groups with progress information.
///
/// Displays:
/// - All skill groups in a scrollable grid
/// - Progress bars showing trained skills per group
/// - Selection state highlighting
/// - Loading/error states
///
/// Tapping a group updates [selectedSkillGroupProvider] to show skills
/// in that group in the lower panel.
class SkillGroupGrid extends ConsumerWidget {
  const SkillGroupGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d('SKILLS.UI', 'SkillGroupGrid - building');
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(skillGroupsWithProgressProvider);
    final selectedGroupId = ref.watch(selectedSkillGroupProvider);

    return Container(
      decoration: BoxDecoration(
        color: EveColors.surfaceDefault,
        borderRadius: BorderRadius.circular(4),
      ),
      child: groupsAsync.when(
        data: (groups) {
          Log.d('SKILLS.UI', 'SkillGroupGrid - rendering ${groups.length} groups');

          if (groups.isEmpty) {
            Log.w('SKILLS.UI', 'SkillGroupGrid - no groups found');
            return SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_off_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Skill Groups',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load skill groups from SDE',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Calculate dynamic height based on number of groups
          final rowCount = (groups.length / 3).ceil();
          final gridHeight = rowCount * 28.0;

          Log.d('SKILLS.UI', 'SkillGroupGrid - $rowCount rows, ${gridHeight}px height');

          return LayoutBuilder(
            builder: (context, constraints) {
              // Calculate aspect ratio to achieve exactly 28px row height
              // cellWidth = available width / 3 columns
              // aspectRatio = cellWidth / desiredHeight
              final cellWidth = constraints.maxWidth / 3;
              final aspectRatio = cellWidth / 28.0;

              Log.d('SKILLS.UI', 'SkillGroupGrid - cellWidth: $cellWidth, aspectRatio: $aspectRatio');

              return SizedBox(
                height: gridHeight,
                child: GridView.count(
                  crossAxisCount: 3,
                  padding: EdgeInsets.zero,
                  mainAxisSpacing: 0,
                  crossAxisSpacing: 0,
                  childAspectRatio: aspectRatio,
                  physics: const NeverScrollableScrollPhysics(),
                  children: groups.map((group) {
                    final isSelected = selectedGroupId == group.group.groupId;

                    return SkillGroupTile(
                      group: group,
                      isSelected: isSelected,
                      onTap: () {
                        Log.d('SKILLS.UI', 'SkillGroupGrid - group ${group.group.groupId} tapped');
                        ref.read(selectedSkillGroupProvider.notifier).state =
                            group.group.groupId;
                      },
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
        loading: () {
          Log.d('SKILLS.UI', 'SkillGroupGrid - loading');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: EveColors.photonBlue,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading skill groups...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
        error: (error, stack) {
          Log.e('SKILLS.UI', 'SkillGroupGrid - error loading groups', error, stack);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to Load Skill Groups',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
