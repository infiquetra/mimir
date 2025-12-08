import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../characters/data/character_providers.dart';
import '../../data/skill_plan_providers.dart';
import '../skill_plan_detail_screen.dart';
import 'skill_plan_card.dart';
import 'skill_plan_editor.dart';

/// Panel displaying skill plans for the active character.
///
/// Shows:
/// - List of all skill plans with progress cards
/// - Floating action button to create new plans
/// - Edit/delete actions on each plan
/// - Empty state with create button
class SkillPlansPanel extends ConsumerWidget {
  const SkillPlansPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d('SKILLS', 'SkillPlansPanel.build - START');
    final activeCharacterAsync = ref.watch(activeCharacterProvider);
    final skillPlansAsync = ref.watch(skillPlansProvider);

    return activeCharacterAsync.when(
      data: (activeCharacter) {
        if (activeCharacter == null) {
          return _buildNoCharacterState(context);
        }

        return skillPlansAsync.when(
          data: (plans) {
            Log.d('SKILLS', 'SkillPlansPanel - ${plans.length} plans');

            if (plans.isEmpty) {
              return _buildEmptyState(context);
            }

            return _buildPlansList(context, ref, plans);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            Log.e('SKILLS', 'SkillPlansPanel - error loading plans', error, stack);
            return _buildErrorState(context, error);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildCharacterErrorState(context, error),
    );
  }

  Widget _buildPlansList(
    BuildContext context,
    WidgetRef ref,
    List plans,
  ) {
    return Stack(
      children: [
        // Plans list
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            return SkillPlanCard(
              plan: plan,
              onTap: () {
                Log.d('SKILLS', 'SkillPlansPanel - navigating to plan ${plan.id}');
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SkillPlanDetailScreen(planId: plan.id),
                  ),
                );
              },
              onEdit: () => _handleEditPlan(context, plan),
              onDelete: () => _handleDeletePlan(context, ref, plan),
            );
          },
        ),

        // Floating action button for creating new plan
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _handleCreatePlan(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_add,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Skill Plans',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a skill plan to track your training goals.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _handleCreatePlan(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Plan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCharacterState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Character Selected',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a character to create skill plans.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Plans',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Character',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreatePlan(BuildContext context) async {
    Log.i('SKILLS', 'SkillPlansPanel - opening create plan dialog');
    await showDialog(
      context: context,
      builder: (context) => const SkillPlanEditor(),
    );
  }

  Future<void> _handleEditPlan(BuildContext context, plan) async {
    Log.i('SKILLS', 'SkillPlansPanel - opening edit plan dialog for ${plan.id}');
    await showDialog(
      context: context,
      builder: (context) => SkillPlanEditor(plan: plan),
    );
  }

  Future<void> _handleDeletePlan(
    BuildContext context,
    WidgetRef ref,
    plan,
  ) async {
    Log.i('SKILLS', 'SkillPlansPanel - showing delete confirmation for plan ${plan.id}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Skill Plan'),
        content: Text(
          'Are you sure you want to delete "${plan.name}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      Log.i('SKILLS', 'SkillPlansPanel - deleting plan ${plan.id}');
      final notifier = ref.read(skillPlanProvider.notifier);
      await notifier.deletePlan(plan.id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan deleted successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e, stack) {
      Log.e('SKILLS', 'SkillPlansPanel - delete failed', e, stack);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete plan: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
