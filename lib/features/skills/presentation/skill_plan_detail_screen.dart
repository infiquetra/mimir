import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_providers.dart';
import '../../../core/theme/eve_colors.dart';
import '../../../core/theme/eve_typography.dart';
import '../../../core/widgets/eve_skill_icon.dart';
import '../data/skill_plan_providers.dart';
import '../data/skill_repository.dart';
import '../../characters/data/character_providers.dart';

/// Detail screen for viewing and managing a skill plan.
///
/// Shows:
/// - Plan name and description
/// - Progress bar (% complete)
/// - List of skills in the plan with target levels
/// - Remove skill button
/// - Reorder skills (drag-and-drop)
/// - Add skills button
class SkillPlanDetailScreen extends ConsumerStatefulWidget {
  const SkillPlanDetailScreen({
    required this.planId,
    super.key,
  });

  final int planId;

  @override
  ConsumerState<SkillPlanDetailScreen> createState() =>
      _SkillPlanDetailScreenState();
}

class _SkillPlanDetailScreenState extends ConsumerState<SkillPlanDetailScreen> {
  @override
  Widget build(BuildContext context) {
    Log.d('SKILLS.PLAN_DETAIL', 'SkillPlanDetailScreen.build - planId: ${widget.planId}');

    final plansAsync = ref.watch(skillPlansProvider);
    final entriesAsync = ref.watch(skillPlanEntriesProvider(widget.planId));
    final progressAsync = ref.watch(skillPlanProgressProvider(widget.planId));

    return Scaffold(
      appBar: AppBar(
        title: plansAsync.when(
          data: (plans) {
            final plan = plans.firstWhere(
              (p) => p.id == widget.planId,
              orElse: () => SkillPlan(
                id: widget.planId,
                characterId: 0,
                name: 'Unknown Plan',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
            return Text(plan.name);
          },
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
        backgroundColor: EveColors.backgroundDeep,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Plan',
            onPressed: () {
              Log.d('SKILLS.PLAN_DETAIL', 'Edit plan tapped - planId: ${widget.planId}');
              // TODO: Show edit plan dialog
            },
          ),
        ],
      ),
      backgroundColor: EveColors.backgroundBase,
      body: Column(
        children: [
          // Progress header
          progressAsync.when(
            data: (progress) => _buildProgressHeader(progress),
            loading: () => const SizedBox(height: 80),
            error: (_, __) => const SizedBox(height: 80),
          ),

          // Skills list
          Expanded(
            child: entriesAsync.when(
              data: (entries) => _buildSkillsList(entries),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                Log.e('SKILLS.PLAN_DETAIL', 'Failed to load plan entries', error, stack);
                return _buildErrorState(error);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Log.d('SKILLS.PLAN_DETAIL', 'Add skills button tapped');
          // TODO: Show skill browser dialog (Phase 3.2)
        },
        backgroundColor: EveColors.photonBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Skills',
          style: EveTypography.bodyMedium(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildProgressHeader(SkillPlanProgress progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: EveColors.surfaceDefault,
        border: Border(
          bottom: BorderSide(color: EveColors.borderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress: ${progress.trainedSkills}/${progress.totalSkills} skills',
                      style: EveTypography.bodyMedium(color: EveColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Est. Time: ${progress.estimatedTimeFormatted}',
                      style: EveTypography.bodySmall(color: EveColors.textTertiary),
                    ),
                  ],
                ),
              ),
              Text(
                '${progress.percentComplete.toStringAsFixed(1)}%',
                style: EveTypography.titleLarge(color: EveColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.percentComplete / 100,
              backgroundColor: EveColors.surfaceBright,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress.percentComplete >= 100
                    ? EveColors.success
                    : EveColors.photonBlue,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsList(List<SkillPlanEntry> entries) {
    if (entries.isEmpty) {
      return _buildEmptyState();
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // Space for FAB
      itemCount: entries.length,
      onReorder: (oldIndex, newIndex) => _handleReorder(entries, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _SkillPlanEntryTile(
          key: ValueKey(entry.id),
          entry: entry,
          onRemove: () => _removeSkill(entry),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt_outlined,
              size: 64,
              color: EveColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Skills in Plan',
              style: EveTypography.titleLarge(color: EveColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add Skills" to get started',
              style: EveTypography.bodyMedium(color: EveColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: EveColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Plan',
              style: EveTypography.titleLarge(color: EveColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: EveTypography.bodyMedium(color: EveColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReorder(
    List<SkillPlanEntry> entries,
    int oldIndex,
    int newIndex,
  ) async {
    Log.d(
      'SKILLS.PLAN_DETAIL',
      '_handleReorder - moving skill from $oldIndex to $newIndex',
    );

    // Adjust newIndex if moving down the list
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // Create new order with skill IDs
    final reorderedSkills = List<SkillPlanEntry>.from(entries);
    final movedEntry = reorderedSkills.removeAt(oldIndex);
    reorderedSkills.insert(newIndex, movedEntry);

    final skillIds = reorderedSkills.map((e) => e.skillId).toList();

    try {
      final notifier = ref.read(skillPlanProvider.notifier);
      await notifier.reorderSkills(widget.planId, skillIds);
      Log.i('SKILLS.PLAN_DETAIL', '_handleReorder - SUCCESS');
    } catch (e, stack) {
      Log.e('SKILLS.PLAN_DETAIL', '_handleReorder - FAILED', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reorder skills: $e'),
            backgroundColor: EveColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeSkill(SkillPlanEntry entry) async {
    Log.d(
      'SKILLS.PLAN_DETAIL',
      '_removeSkill - planId: ${widget.planId}, skillId: ${entry.skillId}',
    );

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EveColors.surfaceElevated,
        title: Text(
          'Remove Skill?',
          style: EveTypography.titleLarge(color: EveColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove this skill from the plan?',
          style: EveTypography.bodyMedium(color: EveColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: EveTypography.bodyMedium(color: EveColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: EveColors.error,
            ),
            child: Text(
              'Remove',
              style: EveTypography.bodyMedium(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      Log.d('SKILLS.PLAN_DETAIL', '_removeSkill - cancelled');
      return;
    }

    try {
      final notifier = ref.read(skillPlanProvider.notifier);
      await notifier.removeSkillFromPlan(widget.planId, entry.skillId);
      Log.i('SKILLS.PLAN_DETAIL', '_removeSkill - SUCCESS');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Skill removed from plan'),
            backgroundColor: EveColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stack) {
      Log.e('SKILLS.PLAN_DETAIL', '_removeSkill - FAILED', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove skill: $e'),
            backgroundColor: EveColors.error,
          ),
        );
      }
    }
  }
}

/// Tile widget for a skill plan entry.
///
/// Shows skill icon, name, target level, and trained level.
class _SkillPlanEntryTile extends ConsumerWidget {
  const _SkillPlanEntryTile({
    required this.entry,
    required this.onRemove,
    super.key,
  });

  final SkillPlanEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillNameAsync = ref.watch(skillNameProvider(entry.skillId));
    final activeCharacter = ref.watch(activeCharacterProvider).value;

    return Material(
      color: EveColors.surfaceDefault,
      child: InkWell(
        onTap: () {
          Log.d('SKILLS.PLAN_DETAIL', 'Skill entry tapped: ${entry.skillId}');
          // TODO: Show skill details dialog
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: EveColors.borderSubtle),
            ),
          ),
          child: Row(
            children: [
              // Drag handle
              Icon(
                Icons.drag_handle,
                color: EveColors.textTertiary,
                size: 20,
              ),
              const SizedBox(width: 12),

              // Skill icon
              EveSkillIcon(
                typeId: entry.skillId,
                size: 40,
              ),
              const SizedBox(width: 12),

              // Skill name and level info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    skillNameAsync.when(
                      data: (name) => Text(
                        name,
                        style: EveTypography.bodyMedium(color: EveColors.textPrimary),
                      ),
                      loading: () => Text(
                        'Loading...',
                        style: EveTypography.bodyMedium(color: EveColors.textSecondary),
                      ),
                      error: (_, __) => Text(
                        'Skill #${entry.skillId}',
                        style: EveTypography.bodyMedium(color: EveColors.error),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildLevelInfo(ref, activeCharacter),
                  ],
                ),
              ),

              // Remove button
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: EveColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'Remove skill',
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelInfo(WidgetRef ref, Character? character) {
    if (character == null) {
      return Text(
        'Target: Level ${entry.targetLevel}',
        style: EveTypography.bodySmall(color: EveColors.textSecondary),
      );
    }

    final repository = ref.read(skillRepositoryProvider);
    return FutureBuilder<int>(
      future: repository.getTrainedLevel(character.characterId, entry.skillId),
      builder: (context, snapshot) {
        final trainedLevel = snapshot.data ?? 0;
        final isComplete = trainedLevel >= entry.targetLevel;

        return Row(
          children: [
            Text(
              'Target: Level ${entry.targetLevel}',
              style: EveTypography.bodySmall(
                color: isComplete ? EveColors.success : EveColors.textSecondary,
              ),
            ),
            if (trainedLevel > 0) ...[
              const SizedBox(width: 8),
              Text(
                '(Trained: $trainedLevel)',
                style: EveTypography.bodySmall(color: EveColors.textTertiary),
              ),
            ],
          ],
        );
      },
    );
  }
}
