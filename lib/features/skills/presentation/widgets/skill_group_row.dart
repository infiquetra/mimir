import 'package:flutter/material.dart';

import '../../../../core/sde/sde_database.dart';
import '../../../../core/widgets/eve_type_icon.dart';

/// Row displaying a skill group in the 3-column catalogue layout.
///
/// Shows:
/// - EVE type icon for the group (32x32)
/// - Group name
/// - Progress bar showing trained skills percentage
/// - Count display "X/Y" (trained/total)
///
/// Example:
/// ```dart
/// SkillGroupRow(
///   group: sdeGroup,
///   trainedCount: 12,
///   totalCount: 45,
///   onTap: () => expandGroup(),
/// )
/// ```
class SkillGroupRow extends StatelessWidget {
  /// The skill group from SDE.
  final SdeGroup group;

  /// Number of skills trained in this group.
  final int trainedCount;

  /// Total number of skills in this group.
  final int totalCount;

  /// Callback when the row is tapped (to expand/collapse group).
  final VoidCallback? onTap;

  /// Whether this group is currently expanded.
  final bool isExpanded;

  const SkillGroupRow({
    super.key,
    required this.group,
    required this.trainedCount,
    required this.totalCount,
    this.onTap,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = totalCount > 0 ? trainedCount / totalCount : 0.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Group icon (use first skill in group as representative icon)
            // For now, use a placeholder icon since we don't have group icons directly
            Container(
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

            const SizedBox(width: 12),

            // Group name and progress bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.groupName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Expansion indicator
                      Icon(
                        isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Count display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$trainedCount/$totalCount',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: trainedCount == totalCount
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
