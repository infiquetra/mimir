import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/logging/logger.dart';
import '../../../../core/sde/sde_database.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/theme/eve_typography.dart';
import '../../../../core/widgets/eve_skill_icon.dart';
import '../../data/skill_plan_providers.dart';

/// Dialog for adding a skill to a plan.
///
/// Allows the user to:
/// - Select target level (1-5)
/// - Select which plan to add to
/// - Add the skill to the selected plan
class AddToPlanDialog extends ConsumerStatefulWidget {
  const AddToPlanDialog({
    required this.skill,
    required this.trainedLevel,
    super.key,
  });

  final SdeType skill;
  final int trainedLevel; // 0-5

  @override
  ConsumerState<AddToPlanDialog> createState() => _AddToPlanDialogState();
}

class _AddToPlanDialogState extends ConsumerState<AddToPlanDialog> {
  int? _selectedPlanId;
  int _targetLevel = 1;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    // Default target level is trainedLevel + 1 (or 5 if already at 5)
    _targetLevel = widget.trainedLevel < 5 ? widget.trainedLevel + 1 : 5;
    Log.d(
      'SKILLS.CATALOGUE',
      'AddToPlanDialog.init - skill: ${widget.skill.typeName}, trained: ${widget.trainedLevel}, default target: $_targetLevel',
    );
  }

  Future<void> _addToPlan() async {
    if (_selectedPlanId == null) {
      Log.w('SKILLS.CATALOGUE', 'AddToPlanDialog._addToPlan - no plan selected');
      return;
    }

    Log.i(
      'SKILLS.CATALOGUE',
      'AddToPlanDialog._addToPlan - adding ${widget.skill.typeName} (level $_targetLevel) to plan $_selectedPlanId',
    );

    setState(() {
      _isAdding = true;
    });

    try {
      final notifier = ref.read(skillPlanProvider.notifier);
      await notifier.addSkillToPlan(
        planId: _selectedPlanId!,
        skillId: widget.skill.typeId,
        targetLevel: _targetLevel,
      );

      Log.i('SKILLS.CATALOGUE', 'AddToPlanDialog._addToPlan - SUCCESS');

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e, stack) {
      Log.e('SKILLS.CATALOGUE', 'AddToPlanDialog._addToPlan - FAILED', e, stack);

      if (mounted) {
        setState(() {
          _isAdding = false;
        });

        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add skill: $e'),
            backgroundColor: EveColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.d('SKILLS.CATALOGUE', 'AddToPlanDialog.build - START');

    final plansAsync = ref.watch(skillPlansProvider);

    return Dialog(
      backgroundColor: EveColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Add to Plan',
              style: EveTypography.titleLarge(color: EveColors.textPrimary),
            ),
            const SizedBox(height: 24),

            // Skill display
            _buildSkillDisplay(),
            const SizedBox(height: 24),

            // Target level selector
            _buildLevelSelector(),
            const SizedBox(height: 24),

            // Plan selector
            plansAsync.when(
              data: (plans) => _buildPlanSelector(plans),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                Log.e('SKILLS.CATALOGUE', 'Failed to load plans', error, stack);
                return _buildErrorState(error);
              },
            ),

            const SizedBox(height: 24),

            // Buttons
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillDisplay() {
    return Row(
      children: [
        EveSkillIcon(
          typeId: widget.skill.typeId,
          size: 48,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.skill.typeName,
                style: EveTypography.titleMedium(color: EveColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Currently trained: Level ${widget.trainedLevel}',
                style: EveTypography.bodySmall(color: EveColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Level',
          style: EveTypography.bodyMedium(color: EveColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final level = index + 1;
            final isDisabled = level <= widget.trainedLevel;
            final isSelected = level == _targetLevel;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$level'),
                selected: isSelected,
                onSelected: isDisabled
                    ? null
                    : (selected) {
                        if (selected) {
                          setState(() {
                            _targetLevel = level;
                          });
                          Log.d(
                            'SKILLS.CATALOGUE',
                            'AddToPlanDialog - target level changed to $level',
                          );
                        }
                      },
                backgroundColor: EveColors.surfaceDefault,
                selectedColor: EveColors.photonBlue,
                disabledColor: EveColors.surfaceDefault.withOpacity(0.5),
                labelStyle: EveTypography.bodyMedium(
                  color: isDisabled
                      ? EveColors.textDisabled
                      : isSelected
                          ? Colors.white
                          : EveColors.textPrimary,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPlanSelector(List<SkillPlan> plans) {
    if (plans.isEmpty) {
      return _buildNoPlansState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add to Plan',
          style: EveTypography.bodyMedium(color: EveColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: EveColors.surfaceDefault,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: EveColors.borderSubtle),
          ),
          child: DropdownButton<int>(
            value: _selectedPlanId,
            hint: Text(
              'Select a plan...',
              style: EveTypography.bodyMedium(color: EveColors.textSecondary),
            ),
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: EveColors.surfaceElevated,
            style: EveTypography.bodyMedium(color: EveColors.textPrimary),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            items: plans.map((plan) {
              return DropdownMenuItem<int>(
                value: plan.id,
                child: Text(plan.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPlanId = value;
              });
              Log.d('SKILLS.CATALOGUE', 'AddToPlanDialog - plan selected: $value');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoPlansState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EveColors.surfaceDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EveColors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: EveColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No skill plans yet. Create one from the Skill Plans tab.',
              style: EveTypography.bodySmall(color: EveColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EveColors.surfaceDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EveColors.error),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: EveColors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Failed to load plans: $error',
              style: EveTypography.bodySmall(color: EveColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    final plansAsync = ref.watch(skillPlansProvider);
    final hasPlans = plansAsync.maybeWhen(
      data: (plans) => plans.isNotEmpty,
      orElse: () => false,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isAdding
              ? null
              : () {
                  Log.d('SKILLS.CATALOGUE', 'AddToPlanDialog - cancelled');
                  Navigator.of(context).pop(false);
                },
          child: Text(
            'Cancel',
            style: EveTypography.bodyMedium(color: EveColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: (_isAdding || !hasPlans || _selectedPlanId == null)
              ? null
              : _addToPlan,
          style: ElevatedButton.styleFrom(
            backgroundColor: EveColors.photonBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: EveColors.surfaceDefault,
            disabledForegroundColor: EveColors.textDisabled,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isAdding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Add to Plan',
                  style: EveTypography.bodyMedium(color: Colors.white),
                ),
        ),
      ],
    );
  }
}
