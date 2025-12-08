import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_database.dart';
import '../../../core/sde/sde_providers.dart';
import '../../characters/data/character_providers.dart';
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
