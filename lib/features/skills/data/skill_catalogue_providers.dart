import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_database.dart';
import '../../../core/sde/sde_providers.dart';
import '../../characters/data/character_providers.dart';
import '../domain/skill_prerequisite_service.dart';
import 'skill_providers.dart';
import 'skill_repository.dart';

// =============================================================================
// Skill Catalogue Data Models
// =============================================================================

/// A skill with its trained level for the active character.
class SkillWithLevel {
  SkillWithLevel({
    required this.skill,
    required this.trainedLevel,
    required this.isTraining,
  });

  final SdeType skill;
  final int trainedLevel; // 0-5
  final bool isTraining;
}

/// A skill group with progress information.
class SkillGroupWithProgress {
  SkillGroupWithProgress({
    required this.group,
    required this.trainedCount,
    required this.totalCount,
  });

  final SdeGroup group;
  final int trainedCount; // Number of skills with level > 0
  final int totalCount; // Total skills in group
}

// =============================================================================
// Skill Groups Provider
// =============================================================================

/// Provider that fetches all skill groups from SDE.
///
/// Returns groups sorted alphabetically by name.
final skillGroupsProvider = FutureProvider<List<SdeGroup>>((ref) async {
  Log.d('SKILLS.CATALOGUE', 'skillGroups - fetching all skill groups from SDE');
  final sde = ref.watch(sdeServiceProvider);
  await sde.initialize();

  final groups = await sde.getSkillGroups();
  Log.i('SKILLS.CATALOGUE', 'skillGroups - fetched ${groups.length} groups');
  return groups;
});

// =============================================================================
// Skills by Group Provider
// =============================================================================

/// Provider that fetches skills in a group with trained levels.
///
/// Returns skills sorted alphabetically, with trained level (0-5)
/// for the active character.
final skillsByGroupProvider =
    FutureProvider.family<List<SkillWithLevel>, int>((ref, groupId) async {
  Log.d('SKILLS.CATALOGUE', 'skillsByGroup - fetching skills for group $groupId');
  final sde = ref.watch(sdeServiceProvider);
  final repository = ref.watch(skillRepositoryProvider);
  final activeCharacter = ref.watch(activeCharacterProvider).value;

  await sde.initialize();

  // Get all skills in the group from SDE
  final skills = await sde.getSkillsByGroup(groupId);
  Log.d('SKILLS.CATALOGUE', 'skillsByGroup - found ${skills.length} skills in group $groupId');

  if (activeCharacter == null) {
    // No character selected - all skills at level 0, not training
    return skills
        .map((skill) => SkillWithLevel(
              skill: skill,
              trainedLevel: 0,
              isTraining: false,
            ))
        .toList();
  }

  // Get trained levels for this character
  final characterId = activeCharacter.characterId;
  final result = <SkillWithLevel>[];

  // Get currently training skill IDs
  final queue = await repository.getSkillQueue(characterId);
  final trainingSkillIds = queue.map((e) => e.skillId).toSet();

  for (final skill in skills) {
    final trainedLevel = await repository.getTrainedLevel(characterId, skill.typeId);
    final isTraining = trainingSkillIds.contains(skill.typeId);

    result.add(SkillWithLevel(
      skill: skill,
      trainedLevel: trainedLevel,
      isTraining: isTraining,
    ));
  }

  Log.i('SKILLS.CATALOGUE', 'skillsByGroup - prepared ${result.length} skills with trained levels');
  return result;
});

// =============================================================================
// Skill Groups with Progress Provider
// =============================================================================

/// Provider that fetches all skill groups with progress information.
///
/// Shows how many skills are trained (level > 0) vs total in each group.
final skillGroupsWithProgressProvider =
    FutureProvider<List<SkillGroupWithProgress>>((ref) async {
  Log.d('SKILLS.CATALOGUE', 'skillGroupsWithProgress - calculating progress for all groups');
  final groups = await ref.watch(skillGroupsProvider.future);
  final activeCharacter = ref.watch(activeCharacterProvider).value;

  if (activeCharacter == null) {
    // No character - all groups show 0/N
    final result = await Future.wait(
      groups.map((group) async {
        final skills = await ref.read(skillsByGroupProvider(group.groupId).future);
        return SkillGroupWithProgress(
          group: group,
          trainedCount: 0,
          totalCount: skills.length,
        );
      }),
    );
    return result;
  }

  // Calculate trained count per group
  final result = <SkillGroupWithProgress>[];
  for (final group in groups) {
    final skillsWithLevel = await ref.read(skillsByGroupProvider(group.groupId).future);
    final trainedCount = skillsWithLevel.where((s) => s.trainedLevel > 0).length;

    result.add(SkillGroupWithProgress(
      group: group,
      trainedCount: trainedCount,
      totalCount: skillsWithLevel.length,
    ));
  }

  Log.i('SKILLS.CATALOGUE', 'skillGroupsWithProgress - calculated progress for ${result.length} groups');
  return result;
});

// =============================================================================
// Search Provider
// =============================================================================

/// Provider that searches skills by name.
///
/// Returns all skills matching the query (case-insensitive substring match).
/// Returns empty list if query is empty or less than 2 characters.
final searchSkillsProvider =
    FutureProvider.family<List<SkillWithLevel>, String>((ref, query) async {
  if (query.isEmpty || query.length < 2) {
    Log.d('SKILLS.CATALOGUE', 'searchSkills - query too short, returning empty');
    return [];
  }

  Log.d('SKILLS.CATALOGUE', 'searchSkills - searching for "$query"');
  final sde = ref.watch(sdeServiceProvider);
  final repository = ref.watch(skillRepositoryProvider);
  final activeCharacter = ref.watch(activeCharacterProvider).value;

  await sde.initialize();

  // Get all skills from SDE
  final allSkills = await sde.database.getAllSkills();
  final lowerQuery = query.toLowerCase();

  // Filter by name (case-insensitive)
  final matchingSkills = allSkills
      .where((skill) => skill.typeName.toLowerCase().contains(lowerQuery))
      .toList();

  Log.d('SKILLS.CATALOGUE', 'searchSkills - found ${matchingSkills.length} matches for "$query"');

  if (activeCharacter == null) {
    return matchingSkills
        .map((skill) => SkillWithLevel(
              skill: skill,
              trainedLevel: 0,
              isTraining: false,
            ))
        .toList();
  }

  // Get trained levels
  final characterId = activeCharacter.characterId;
  final queue = await repository.getSkillQueue(characterId);
  final trainingSkillIds = queue.map((e) => e.skillId).toSet();

  final result = <SkillWithLevel>[];
  for (final skill in matchingSkills) {
    final trainedLevel = await repository.getTrainedLevel(characterId, skill.typeId);
    final isTraining = trainingSkillIds.contains(skill.typeId);

    result.add(SkillWithLevel(
      skill: skill,
      trainedLevel: trainedLevel,
      isTraining: isTraining,
    ));
  }

  Log.i('SKILLS.CATALOGUE', 'searchSkills - prepared ${result.length} skills with levels');
  return result;
});

// =============================================================================
// Filter and Selection Providers
// =============================================================================

/// Filter modes for the skill catalogue.
enum SkillFilterMode {
  all, // All skills
  mySkills, // Only trained skills (level > 0)
  canTrain, // Can train now (prereqs met, not at max level)
  havePrereqs, // Have all prerequisites met
}

/// Current filter mode selection.
final skillFilterModeProvider = StateProvider<SkillFilterMode>((ref) {
  return SkillFilterMode.all;
});

/// Currently selected skill group ID.
final selectedSkillGroupProvider = StateProvider<int?>((ref) => null);

/// Search query state.
final skillSearchQueryProvider = StateProvider<String>((ref) => '');

// =============================================================================
// Group Representative Skill Provider
// =============================================================================

/// Fetches the representative skill typeId for a group (used for icons).
///
/// Returns the first skill in the group alphabetically, or null if group is empty.
final groupRepresentativeSkillProvider =
    FutureProvider.family<int?, int>((ref, groupId) async {
  Log.d('SKILLS.CATALOGUE', 'groupRepresentativeSkill - fetching for group $groupId');
  final sde = ref.watch(sdeServiceProvider);
  await sde.initialize();

  final skills = await sde.getSkillsByGroup(groupId);
  if (skills.isEmpty) {
    Log.w('SKILLS.CATALOGUE', 'groupRepresentativeSkill - group $groupId has no skills');
    return null;
  }

  final representativeId = skills.first.typeId;
  Log.d('SKILLS.CATALOGUE', 'groupRepresentativeSkill - using typeId $representativeId for group $groupId');
  return representativeId;
});

// =============================================================================
// Filtered Skills Provider
// =============================================================================

/// Provides skills filtered by the current filter mode.
final filteredSkillsByGroupProvider =
    FutureProvider.family<List<SkillWithLevel>, int>((ref, groupId) async {
  final allSkills = await ref.watch(skillsByGroupProvider(groupId).future);
  final filterMode = ref.watch(skillFilterModeProvider);
  final activeCharacter = ref.watch(activeCharacterProvider).value;

  Log.d('SKILLS.CATALOGUE', 'filteredSkillsByGroup - filtering ${allSkills.length} skills with mode $filterMode');

  switch (filterMode) {
    case SkillFilterMode.all:
      return allSkills;

    case SkillFilterMode.mySkills:
      final filtered = allSkills.where((s) => s.trainedLevel > 0).toList();
      Log.d('SKILLS.CATALOGUE', 'filteredSkillsByGroup - mySkills: ${filtered.length} trained');
      return filtered;

    case SkillFilterMode.canTrain:
      if (activeCharacter == null) return [];

      final prereqService = ref.read(skillPrerequisiteServiceProvider);
      final characterId = activeCharacter.characterId;
      final result = <SkillWithLevel>[];

      for (final skill in allSkills) {
        // Can train if: not at max level AND prereqs met
        if (skill.trainedLevel >= 5) continue; // Already at max

        final canTrain = await prereqService.canTrainSkill(
          characterId: characterId,
          skillId: skill.skill.typeId,
          targetLevel: skill.trainedLevel + 1,
        );

        if (canTrain) {
          result.add(skill);
        }
      }

      Log.d('SKILLS.CATALOGUE', 'filteredSkillsByGroup - canTrain: ${result.length} skills');
      return result;

    case SkillFilterMode.havePrereqs:
      if (activeCharacter == null) return [];

      final prereqService = ref.read(skillPrerequisiteServiceProvider);
      final characterId = activeCharacter.characterId;
      final result = <SkillWithLevel>[];

      for (final skill in allSkills) {
        if (skill.trainedLevel >= 5) continue; // Already trained

        final canTrain = await prereqService.canTrainSkill(
          characterId: characterId,
          skillId: skill.skill.typeId,
          targetLevel: skill.trainedLevel + 1,
        );

        if (canTrain) {
          result.add(skill);
        }
      }

      Log.d('SKILLS.CATALOGUE', 'filteredSkillsByGroup - havePrereqs: ${result.length} skills');
      return result;
  }
});

// =============================================================================
// Search Matching Groups Provider
// =============================================================================

/// Returns the set of group IDs that contain skills matching the search query.
final searchMatchingGroupsProvider = Provider<Set<int>>((ref) {
  final query = ref.watch(skillSearchQueryProvider);

  if (query.isEmpty || query.length < 2) {
    return {};
  }

  // This is a synchronous provider that relies on the async searchSkillsProvider
  // We'll need to handle the async nature in the UI
  return {}; // Placeholder - will be computed in UI based on search results
});

// =============================================================================
// Queue Statistics Provider
// =============================================================================

/// Queue statistics data model.
class QueueStats {
  QueueStats({
    required this.totalTrainingTime,
    required this.totalSkillPoints,
    required this.queueSize,
  });

  final Duration totalTrainingTime;
  final int totalSkillPoints;
  final int queueSize;
}

/// Provides queue statistics (total time, SP, count).
final queueStatsProvider = Provider<QueueStats>((ref) {
  final queueAsync = ref.watch(skillQueueProvider);

  return queueAsync.when(
    data: (queue) {
      if (queue.isEmpty) {
        return QueueStats(
          totalTrainingTime: Duration.zero,
          totalSkillPoints: 0,
          queueSize: 0,
        );
      }

      // Calculate total training time (sum of remaining times)
      final now = DateTime.now();
      var totalTime = Duration.zero;
      var totalSp = 0;

      for (final entry in queue) {
        if (entry.finishDate != null) {
          final remaining = entry.finishDate!.difference(now);
          if (remaining.isNegative) continue; // Skip completed entries

          totalTime += remaining;
        }

        // Calculate SP for this level
        // SP = levelEndSp - trainingStartSp
        if (entry.levelEndSp != null && entry.trainingStartSp != null) {
          totalSp += entry.levelEndSp! - entry.trainingStartSp!;
        }
      }

      Log.d('SKILLS.CATALOGUE', 'queueStats - time: ${totalTime.inHours}h, SP: $totalSp, size: ${queue.length}');

      return QueueStats(
        totalTrainingTime: totalTime,
        totalSkillPoints: totalSp,
        queueSize: queue.length,
      );
    },
    loading: () => QueueStats(
      totalTrainingTime: Duration.zero,
      totalSkillPoints: 0,
      queueSize: 0,
    ),
    error: (_, __) => QueueStats(
      totalTrainingTime: Duration.zero,
      totalSkillPoints: 0,
      queueSize: 0,
    ),
  );
});
