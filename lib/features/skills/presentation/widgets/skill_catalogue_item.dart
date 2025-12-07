import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sde/sde_database.dart';
import '../../../../core/widgets/eve_skill_icon.dart';
import 'skill_level_indicator.dart';

/// Individual skill row displayed under an expanded skill group.
///
/// Shows:
/// - Skill icon (32x32)
/// - Skill name
/// - Level indicator (5 squares showing trained level)
/// - Optional "currently training" indicator
///
/// Example:
/// ```dart
/// SkillCatalogueItem(
///   skill: sdeType,
///   trainedLevel: 3,
///   isTraining: false,
/// )
/// ```
class SkillCatalogueItem extends ConsumerWidget {
  /// The skill type from SDE.
  final SdeType skill;

  /// Current trained level (0-5).
  final int trainedLevel;

  /// Whether this skill is currently training.
  final bool isTraining;

  /// Optional target level (for skill plans).
  final int? targetLevel;

  /// Callback when the skill is tapped.
  final VoidCallback? onTap;

  const SkillCatalogueItem({
    super.key,
    required this.skill,
    required this.trainedLevel,
    this.isTraining = false,
    this.targetLevel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            // Skill icon
            EveSkillIcon(
              skillId: skill.typeId,
              size: 32,
            ),

            const SizedBox(width: 12),

            // Skill name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          skill.typeName,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isTraining) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'TRAINING',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Level indicator
            SkillLevelIndicator(
              trainedLevel: trainedLevel,
              targetLevel: targetLevel,
              isTraining: isTraining,
            ),
          ],
        ),
      ),
    );
  }
}
