import 'package:flutter/material.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/eve_skill_icon.dart';
import '../../data/skill_catalogue_providers.dart';
import 'add_to_plan_dialog.dart';
import 'skill_level_indicator.dart';

/// A compact item representing a single skill in the 2-column skill list.
///
/// Displays:
/// - Skill icon (64x64)
/// - Skill name
/// - Level indicator (5 squares showing progress)
/// - Add to plan button (+)
/// - Red translucent background if character can't train
/// - Training indicator (animated pulse) if currently training
///
/// Tapping the + button opens [AddToPlanDialog] to add skill to a plan.
class SkillListItem extends StatelessWidget {
  const SkillListItem({
    super.key,
    required this.skill,
    required this.canTrain,
  });

  final SkillWithLevel skill;
  final bool canTrain;

  @override
  Widget build(BuildContext context) {
    Log.d('SKILLS.UI', 'SkillListItem - rendering ${skill.skill.typeName}');
    final theme = Theme.of(context);

    // Red translucent background for untrainable skills
    final backgroundColor = canTrain
        ? EveColors.surfaceDefault
        : EveColors.error.withOpacity(0.15);

    // Dimmed text for untrainable skills
    final textColor = canTrain
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withOpacity(0.6);

    return InkWell(
      onTap: canTrain
          ? () {
              Log.d('SKILLS.UI', 'SkillListItem - tapped ${skill.skill.typeName}');
              // Could navigate to skill details here in future
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // Skill icon (64x64)
            EveSkillIcon(
              typeId: skill.skill.typeId,
              size: 48,
            ),
            const SizedBox(width: 12),

            // Skill name and level indicator
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skill name
                  Text(
                    skill.skill.typeName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Level indicator with training animation
                  Row(
                    children: [
                      SkillLevelIndicator(
                        trainedLevel: skill.trainedLevel,
                        isTraining: skill.isTraining,
                        size: 16,
                        spacing: 3,
                      ),
                      if (skill.isTraining) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.trending_up,
                          size: 16,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Training',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Add to plan button
            if (skill.trainedLevel < 5) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  Log.d('SKILLS.UI', 'SkillListItem - add to plan: ${skill.skill.typeName}');
                  showDialog(
                    context: context,
                    builder: (context) => AddToPlanDialog(
                      skill: skill.skill,
                      trainedLevel: skill.trainedLevel,
                    ),
                  );
                },
                icon: Icon(
                  Icons.add_circle_outline,
                  color: canTrain
                      ? EveColors.photonBlue
                      : theme.colorScheme.onSurface.withOpacity(0.3),
                ),
                tooltip: canTrain
                    ? 'Add to Skill Plan'
                    : 'Cannot train (prerequisites not met)',
                iconSize: 24,
              ),
            ] else ...[
              // Max level indicator
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Max',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
