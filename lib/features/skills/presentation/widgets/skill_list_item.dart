import 'package:flutter/material.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../data/skill_catalogue_providers.dart';
import 'add_to_plan_dialog.dart';
import 'skill_level_indicator.dart';

/// A compact row representing a single skill in the 2-column skill list.
///
/// Displays (EVE Online style):
/// - Level indicator (5 squares) on LEFT
/// - Skill name to the RIGHT of level indicator
/// - Training status or time on far right
/// - Add button (+) or Max indicator
///
/// Layout:
/// ```
/// ■■■□□  Advanced Weapon Upgrades    Training  [+]
/// ■■■■■  Gunnery                               Max
/// ```
///
/// Very compact (~40px height), no card borders, just subtle row styling.
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
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.transparent,
        ),
        child: Row(
          children: [
            // Level indicator (5 squares) on LEFT
            SkillLevelIndicator(
              trainedLevel: skill.trainedLevel,
              isTraining: skill.isTraining,
              size: 14,
              spacing: 3,
            ),
            const SizedBox(width: 12),

            // Skill name
            Expanded(
              child: Text(
                skill.skill.typeName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Training status indicator
            if (skill.isTraining) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: EveColors.photonCyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 12,
                      color: EveColors.photonCyan,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Training',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: EveColors.photonCyan,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Unpurchased skill indicator (red book icon)
            if (!skill.isInjected) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: EveColors.error.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.book,
                  size: 16,
                  color: EveColors.error,
                ),
              ),
            ],

            const SizedBox(width: 8),

            // Add to plan button OR Max indicator
            if (skill.trainedLevel < 5)
              IconButton(
                onPressed: canTrain
                    ? () {
                        Log.d('SKILLS.UI', 'SkillListItem - add to plan: ${skill.skill.typeName}');
                        showDialog(
                          context: context,
                          builder: (context) => AddToPlanDialog(
                            skill: skill.skill,
                            trainedLevel: skill.trainedLevel,
                          ),
                        );
                      }
                    : null,
                icon: Icon(
                  Icons.add_circle_outline,
                  color: canTrain
                      ? EveColors.photonBlue
                      : theme.colorScheme.onSurface.withOpacity(0.3),
                ),
                tooltip: canTrain
                    ? 'Add to Skill Plan'
                    : 'Cannot train (prerequisites not met)',
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              // Max level indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Max',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
