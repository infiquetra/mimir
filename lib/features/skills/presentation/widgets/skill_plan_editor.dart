import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/logging/logger.dart';
import '../../data/skill_plan_providers.dart';

/// Dialog for creating or editing a skill plan.
///
/// Shows:
/// - Plan name text field (required)
/// - Plan description text field (optional, multiline)
/// - Save/Cancel buttons
///
/// Usage:
/// ```dart
/// // Create new plan
/// await showDialog(
///   context: context,
///   builder: (context) => const SkillPlanEditor(),
/// );
///
/// // Edit existing plan
/// await showDialog(
///   context: context,
///   builder: (context) => SkillPlanEditor(plan: existingPlan),
/// );
/// ```
class SkillPlanEditor extends ConsumerStatefulWidget {
  /// The plan to edit. If null, creates a new plan.
  final SkillPlan? plan;

  const SkillPlanEditor({
    super.key,
    this.plan,
  });

  @override
  ConsumerState<SkillPlanEditor> createState() => _SkillPlanEditorState();
}

class _SkillPlanEditorState extends ConsumerState<SkillPlanEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isSaving = false;

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plan?.name ?? '');
    _descriptionController = TextEditingController(text: widget.plan?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Skill Plan' : 'Create Skill Plan'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Plan Name',
                  hintText: 'e.g., PvP Frigate Skills',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Plan name is required';
                  }
                  if (value.trim().length > 100) {
                    return 'Plan name must be 100 characters or less';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Plan description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Training plan for T2 frigate PvP',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value != null && value.trim().length > 500) {
                    return 'Description must be 500 characters or less';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 8),

              // Helper text
              Text(
                _isEditing
                    ? 'Update plan name and description. Skills are managed separately.'
                    : 'Create a new skill plan. You can add skills after creation.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),

        // Save button
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(skillPlanNotifierProvider.notifier);
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      if (_isEditing) {
        Log.i('SKILLS', 'SkillPlanEditor - updating plan ${widget.plan!.id}');
        await notifier.updatePlan(
          planId: widget.plan!.id,
          name: name,
          description: description.isNotEmpty ? description : null,
        );
      } else {
        Log.i('SKILLS', 'SkillPlanEditor - creating new plan: $name');
        await notifier.createPlan(
          name: name,
          description: description.isNotEmpty ? description : null,
        );
      }

      if (!mounted) return;

      // Close dialog with success
      Navigator.of(context).pop(true);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Plan updated successfully' : 'Plan created successfully',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, stack) {
      Log.e('SKILLS', 'SkillPlanEditor - save failed', e, stack);

      if (!mounted) return;

      setState(() => _isSaving = false);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save plan: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
