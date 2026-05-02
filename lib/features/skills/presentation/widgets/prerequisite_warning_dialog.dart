import 'package:flutter/material.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/theme/eve_typography.dart';
import '../../../../core/widgets/eve_skill_icon.dart';
import '../../domain/skill_prerequisite_service.dart';

/// Dialog shown when a skill has unmet prerequisites.
///
/// Displays:
/// - List of unmet prerequisites with their required levels
/// - Visual indicators for trained vs required levels
/// - Options to:
///   - Cancel (don't add skill)
///   - Add anyway (add just the skill, ignore prerequisites)
///   - Add with prerequisites (auto-add all missing prerequisites)
class PrerequisiteWarningDialog extends StatelessWidget {
  const PrerequisiteWarningDialog({
    required this.skillId,
    required this.skillName,
    required this.targetLevel,
    required this.unmetPrerequisites,
    super.key,
  });

  final int skillId;
  final String skillName;
  final int targetLevel;
  final List<PrerequisiteRequirement> unmetPrerequisites;

  @override
  Widget build(BuildContext context) {
    Log.d(
      'SKILLS.PREREQ_DIALOG',
      'PrerequisiteWarningDialog.build - skill: $skillName, unmet: ${unmetPrerequisites.length}',
    );

    return Dialog(
      backgroundColor: EveColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: EveColors.warning,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Unmet Prerequisites',
                    style: EveTypography.titleLarge(color: EveColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Skill being added
            _buildSkillHeader(),
            const SizedBox(height: 16),

            // Warning message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EveColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: EveColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: EveColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This skill requires the following prerequisites to be trained first:',
                      style: EveTypography.bodySmall(color: EveColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Prerequisites list
            Text(
              'Missing Prerequisites',
              style: EveTypography.titleSmall(color: EveColors.textSecondary),
            ),
            const SizedBox(height: 8),
            _buildPrerequisitesList(),
            const SizedBox(height: 24),

            // Action buttons
            _buildButtons(context),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildSkillHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EveColors.surfaceDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EveColors.borderSubtle),
      ),
      child: Row(
        children: [
          EveSkillIcon(
            typeId: skillId,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skillName,
                  style: EveTypography.titleMedium(color: EveColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Target: Level $targetLevel',
                  style: EveTypography.bodySmall(color: EveColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrerequisitesList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: EveColors.surfaceDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EveColors.borderSubtle),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: unmetPrerequisites.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: EveColors.borderSubtle,
        ),
        itemBuilder: (context, index) {
          final prereq = unmetPrerequisites[index];
          return _PrerequisiteItem(prereq: prereq);
        },
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        // Add with prerequisites button (recommended)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Log.i(
                'SKILLS.PREREQ_DIALOG',
                'Add with prerequisites - adding skill + ${unmetPrerequisites.length} prerequisites',
              );
              Navigator.of(context).pop(PrerequisiteDialogResult.addWithPrerequisites);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EveColors.photonBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            icon: const Icon(Icons.check_circle, size: 20),
            label: Text(
              'Add with Prerequisites (Recommended)',
              style: EveTypography.bodyMedium(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary buttons row
        Row(
          children: [
            // Cancel button
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Log.d('SKILLS.PREREQ_DIALOG', 'Cancelled - skill not added');
                  Navigator.of(context).pop(PrerequisiteDialogResult.cancel);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: EveColors.textSecondary,
                  side: BorderSide(color: EveColors.borderSubtle),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Cancel',
                  style: EveTypography.bodyMedium(color: EveColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Add anyway button (risky)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Log.w(
                    'SKILLS.PREREQ_DIALOG',
                    'Add anyway - adding skill WITHOUT prerequisites (risky)',
                  );
                  Navigator.of(context).pop(PrerequisiteDialogResult.addAnyway);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: EveColors.warning,
                  side: BorderSide(color: EveColors.warning),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Add Anyway',
                  style: EveTypography.bodyMedium(color: EveColors.warning),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Item widget for a single prerequisite requirement.
class _PrerequisiteItem extends StatelessWidget {
  const _PrerequisiteItem({required this.prereq});

  final PrerequisiteRequirement prereq;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Status icon
          Icon(
            prereq.isUntrained ? Icons.close : Icons.arrow_upward,
            color: prereq.isUntrained ? EveColors.error : EveColors.warning,
            size: 20,
          ),
          const SizedBox(width: 12),

          // Skill icon
          EveSkillIcon(
            typeId: prereq.skillId,
            size: 32,
          ),
          const SizedBox(width: 12),

          // Skill info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prereq.skillName,
                  style: EveTypography.bodyMedium(color: EveColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  prereq.isUntrained
                      ? 'Need level ${prereq.requiredLevel} (untrained)'
                      : 'Need level ${prereq.requiredLevel} (have ${prereq.trainedLevel})',
                  style: EveTypography.bodySmall(
                    color: prereq.isUntrained
                        ? EveColors.error
                        : EveColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Result of the prerequisite warning dialog.
enum PrerequisiteDialogResult {
  /// User cancelled - don't add the skill.
  cancel,

  /// User chose to add the skill anyway without prerequisites.
  addAnyway,

  /// User chose to add the skill with all prerequisites.
  addWithPrerequisites,
}
