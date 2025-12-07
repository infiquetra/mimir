import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';
import '../../characters/data/character_providers.dart';
import 'skill_providers.dart';

part 'skill_plan_providers.g.dart';

// =========================================================================
// Skill Plans Stream Providers
// =========================================================================

/// Provider that streams skill plans for the active character.
///
/// Returns all skill plans sorted by last updated (most recent first).
final skillPlansProvider = StreamProvider<List<SkillPlan>>((ref) {
  final activeCharacter = ref.watch(activeCharacterProvider).value;
  if (activeCharacter == null) {
    Log.d('SKILLS', 'skillPlansProvider - no active character, returning empty stream');
    return Stream.value([]);
  }

  Log.d('SKILLS', 'skillPlansProvider - setting up stream for character ${activeCharacter.characterId}');
  final database = ref.watch(databaseProvider);
  return database.watchSkillPlans(activeCharacter.characterId);
});

/// Provider for skill plan entries for a specific plan.
///
/// Returns entries sorted by sort order (display order).
final skillPlanEntriesProvider = StreamProvider.family<List<SkillPlanEntry>, int>((ref, planId) {
  Log.d('SKILLS', 'skillPlanEntriesProvider - setting up stream for plan $planId');
  final database = ref.watch(databaseProvider);
  return database.watchPlanEntries(planId);
});

/// Provider for skill plan progress calculation.
///
/// Compares plan target levels against character's trained skills.
/// Returns progress data including completion percentage and training time.
final skillPlanProgressProvider = FutureProvider.family<SkillPlanProgress, int>((ref, planId) async {
  Log.d('SKILLS', 'skillPlanProgressProvider - calculating progress for plan $planId');

  final database = ref.read(databaseProvider);
  final activeCharacter = ref.watch(activeCharacterProvider).value;

  if (activeCharacter == null) {
    Log.w('SKILLS', 'skillPlanProgressProvider - no active character');
    return SkillPlanProgress(
      planId: planId,
      totalSkills: 0,
      trainedSkills: 0,
      percentComplete: 0.0,
      totalSpRequired: 0,
      estimatedTimeSeconds: 0,
    );
  }

  // Get plan entries
  final entries = await database.getPlanEntries(planId);
  Log.d('SKILLS', 'skillPlanProgressProvider - plan has ${entries.length} entries');

  if (entries.isEmpty) {
    return SkillPlanProgress(
      planId: planId,
      totalSkills: 0,
      trainedSkills: 0,
      percentComplete: 100.0,
      totalSpRequired: 0,
      estimatedTimeSeconds: 0,
    );
  }

  // Get trained skills
  final trainedSkills = await database.getCharacterSkills(activeCharacter.characterId);
  final trainedSkillsMap = <int, int>{};
  for (final skill in trainedSkills) {
    trainedSkillsMap[skill.skillId] = skill.trainedSkillLevel;
  }

  // Calculate progress
  int trainedCount = 0;
  for (final entry in entries) {
    final trainedLevel = trainedSkillsMap[entry.skillId] ?? 0;
    if (trainedLevel >= entry.targetLevel) {
      trainedCount++;
    }
  }

  final percentComplete = (trainedCount / entries.length * 100);
  Log.i('SKILLS', 'skillPlanProgressProvider - $trainedCount/${entries.length} skills complete (${percentComplete.toStringAsFixed(1)}%)');

  return SkillPlanProgress(
    planId: planId,
    totalSkills: entries.length,
    trainedSkills: trainedCount,
    percentComplete: percentComplete,
    totalSpRequired: 0, // TODO: Calculate from skill requirements
    estimatedTimeSeconds: 0, // TODO: Calculate from training time
  );
});

// =========================================================================
// Skill Plan Notifier (CRUD Operations)
// =========================================================================

/// Notifier for skill plan mutations (create, update, delete).
///
/// Handles all skill plan CRUD operations with proper error handling
/// and logging.
@riverpod
class SkillPlanNotifier extends _$SkillPlanNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  /// Creates a new skill plan.
  Future<int> createPlan({
    required String name,
    String? description,
  }) async {
    Log.i('SKILLS', 'SkillPlanNotifier.createPlan - name: $name');
    state = const AsyncValue.loading();

    try {
      final activeCharacter = ref.read(activeCharacterProvider).value;
      if (activeCharacter == null) {
        throw Exception('No active character');
      }

      final database = ref.read(databaseProvider);
      final planId = await database.createSkillPlan(
        characterId: activeCharacter.characterId,
        name: name,
        description: description,
      );

      Log.i('SKILLS', 'SkillPlanNotifier.createPlan - created plan $planId');
      state = const AsyncValue.data(null);
      return planId;
    } catch (e, stack) {
      Log.e('SKILLS', 'SkillPlanNotifier.createPlan - FAILED', e, stack);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Updates an existing skill plan.
  Future<void> updatePlan({
    required int planId,
    String? name,
    String? description,
  }) async {
    Log.i('SKILLS', 'SkillPlanNotifier.updatePlan - planId: $planId');
    state = const AsyncValue.loading();

    try {
      final database = ref.read(databaseProvider);
      await database.updateSkillPlan(
        planId: planId,
        name: name,
        description: description,
      );

      Log.i('SKILLS', 'SkillPlanNotifier.updatePlan - updated plan $planId');
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      Log.e('SKILLS', 'SkillPlanNotifier.updatePlan - FAILED', e, stack);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Deletes a skill plan and all its entries.
  Future<void> deletePlan(int planId) async {
    Log.i('SKILLS', 'SkillPlanNotifier.deletePlan - planId: $planId');
    state = const AsyncValue.loading();

    try {
      final database = ref.read(databaseProvider);
      await database.deleteSkillPlan(planId);

      Log.i('SKILLS', 'SkillPlanNotifier.deletePlan - deleted plan $planId');
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      Log.e('SKILLS', 'SkillPlanNotifier.deletePlan - FAILED', e, stack);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Adds a skill to a plan.
  Future<void> addSkillToPlan({
    required int planId,
    required int skillId,
    required int targetLevel,
  }) async {
    Log.i('SKILLS', 'SkillPlanNotifier.addSkillToPlan - planId: $planId, skillId: $skillId, level: $targetLevel');
    state = const AsyncValue.loading();

    try {
      final database = ref.read(databaseProvider);

      // Get current entries to determine next sort order
      final entries = await database.getPlanEntries(planId);
      final nextSortOrder = entries.isEmpty ? 0 : entries.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

      await database.addSkillToPlan(
        planId: planId,
        skillId: skillId,
        targetLevel: targetLevel,
        sortOrder: nextSortOrder,
      );

      Log.i('SKILLS', 'SkillPlanNotifier.addSkillToPlan - added skill $skillId to plan $planId');
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      Log.e('SKILLS', 'SkillPlanNotifier.addSkillToPlan - FAILED', e, stack);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Removes a skill from a plan.
  Future<void> removeSkillFromPlan(int planId, int skillId) async {
    Log.i('SKILLS', 'SkillPlanNotifier.removeSkillFromPlan - planId: $planId, skillId: $skillId');
    state = const AsyncValue.loading();

    try {
      final database = ref.read(databaseProvider);
      await database.removeSkillFromPlan(planId, skillId);

      Log.i('SKILLS', 'SkillPlanNotifier.removeSkillFromPlan - removed skill $skillId from plan $planId');
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      Log.e('SKILLS', 'SkillPlanNotifier.removeSkillFromPlan - FAILED', e, stack);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Reorders skills in a plan.
  Future<void> reorderSkills(int planId, List<int> skillIds) async {
    Log.i('SKILLS', 'SkillPlanNotifier.reorderSkills - planId: $planId, ${skillIds.length} skills');
    state = const AsyncValue.loading();

    try {
      final database = ref.read(databaseProvider);
      await database.updatePlanEntryOrder(planId, skillIds);

      Log.i('SKILLS', 'SkillPlanNotifier.reorderSkills - updated order for plan $planId');
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      Log.e('SKILLS', 'SkillPlanNotifier.reorderSkills - FAILED', e, stack);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

// =========================================================================
// Data Models
// =========================================================================

/// Progress data for a skill plan.
class SkillPlanProgress {
  final int planId;
  final int totalSkills;
  final int trainedSkills;
  final double percentComplete;
  final int totalSpRequired;
  final int estimatedTimeSeconds;

  const SkillPlanProgress({
    required this.planId,
    required this.totalSkills,
    required this.trainedSkills,
    required this.percentComplete,
    required this.totalSpRequired,
    required this.estimatedTimeSeconds,
  });

  /// Formatted training time estimate (e.g., "5d 14h 30m").
  String get estimatedTimeFormatted {
    if (estimatedTimeSeconds == 0) return '—';

    final duration = Duration(seconds: estimatedTimeSeconds);
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
