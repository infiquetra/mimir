import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import '../../characters/data/character_providers.dart';
import 'skill_repository.dart';

/// Provider that streams the skill queue for the active character.
///
/// Automatically updates when the active character changes or
/// when the skill queue is refreshed.
final skillQueueProvider = StreamProvider<List<SkillQueueEntry>>((ref) {
  final activeCharacter = ref.watch(activeCharacterProvider).value;
  if (activeCharacter == null) {
    Log.d('SKILLS', 'skillQueueProvider - no active character, returning empty stream');
    return Stream.value([]);
  }

  Log.d('SKILLS', 'skillQueueProvider - setting up stream for character ${activeCharacter.characterId}');
  final repository = ref.watch(skillRepositoryProvider);
  return repository.watchSkillQueue(activeCharacter.characterId);
});

/// Provider for the currently training skill (position 0 in queue).
final currentTrainingProvider = Provider<SkillQueueEntry?>((ref) {
  final queue = ref.watch(skillQueueProvider).value ?? [];
  if (queue.isEmpty) return null;

  // Find the skill at position 0 (currently training).
  return queue.firstWhere(
    (entry) => entry.queuePosition == 0,
    orElse: () => queue.first,
  );
});

/// Provider for the skill queue preview (first 3 skills for Dashboard).
final skillQueuePreviewProvider = Provider<List<SkillQueueEntry>>((ref) {
  final queue = ref.watch(skillQueueProvider).value ?? [];
  return queue.take(3).toList();
});

/// Provider for refreshing the skill queue from ESI.
final refreshSkillQueueProvider =
    FutureProvider.family<void, int>((ref, characterId) async {
  Log.i('SKILLS', 'refreshSkillQueueProvider - invoked for character $characterId');
  final repository = ref.read(skillRepositoryProvider);
  await repository.refreshSkillQueue(characterId);
});

/// Provider that indicates if the skill queue is empty.
final isSkillQueueEmptyProvider = Provider<bool>((ref) {
  final queue = ref.watch(skillQueueProvider).value ?? [];
  return queue.isEmpty;
});

/// Provider that indicates if skill queue is loading.
final isSkillQueueLoadingProvider = Provider<bool>((ref) {
  return ref.watch(skillQueueProvider).isLoading;
});

// =========================================================================
// Trained Skills Providers
// =========================================================================

/// Provider that streams trained skills for the active character.
///
/// Returns all skills the character has trained with their levels and SP.
final characterSkillsProvider = StreamProvider<List<CharacterSkill>>((ref) {
  final activeCharacter = ref.watch(activeCharacterProvider).value;
  if (activeCharacter == null) {
    Log.d('SKILLS', 'characterSkillsProvider - no active character, returning empty stream');
    return Stream.value([]);
  }

  Log.d('SKILLS', 'characterSkillsProvider - setting up stream for character ${activeCharacter.characterId}');
  final repository = ref.watch(skillRepositoryProvider);
  return repository.watchCharacterSkills(activeCharacter.characterId);
});

/// Provider for total skill points for the active character.
///
/// Sums all SP across all trained skills. Returns 0 if no character selected
/// or if skills haven't been fetched yet.
final totalSkillPointsProvider = FutureProvider<int>((ref) async {
  final activeCharacter = ref.watch(activeCharacterProvider).value;
  if (activeCharacter == null) {
    Log.d('SKILLS', 'totalSkillPointsProvider - no active character, returning 0');
    return 0;
  }

  Log.d('SKILLS', 'totalSkillPointsProvider - calculating for character ${activeCharacter.characterId}');
  final repository = ref.read(skillRepositoryProvider);

  // Try database first (faster)
  final skills = await repository.getCharacterSkills(activeCharacter.characterId);
  if (skills.isEmpty) {
    // No cached skills, fetch from ESI
    Log.i('SKILLS', 'totalSkillPointsProvider - no cached skills, fetching from ESI');
    await repository.refreshCharacterSkills(activeCharacter.characterId);
    final freshSkills = await repository.getCharacterSkills(activeCharacter.characterId);
    final total = freshSkills.fold<int>(0, (sum, skill) => sum + skill.skillpointsInSkill);
    Log.i('SKILLS', 'totalSkillPointsProvider - total SP: $total');
    return total;
  }

  final total = skills.fold<int>(0, (sum, skill) => sum + skill.skillpointsInSkill);
  Log.i('SKILLS', 'totalSkillPointsProvider - total SP from cache: $total');
  return total;
});

/// Provider for unallocated skill points.
///
/// Fetches from ESI getSkills() endpoint. Returns null if not available.
/// Note: This requires a fresh ESI fetch as unallocated SP changes.
final unallocatedSpProvider = FutureProvider<int?>((ref) async {
  final activeCharacter = ref.watch(activeCharacterProvider).value;
  if (activeCharacter == null) {
    Log.d('SKILLS', 'unallocatedSpProvider - no active character');
    return null;
  }

  Log.d('SKILLS', 'unallocatedSpProvider - fetching for character ${activeCharacter.characterId}');
  final esiClient = ref.read(esiClientProvider);

  try {
    final characterSkills = await esiClient.getSkills(activeCharacter.characterId);
    Log.i('SKILLS', 'unallocatedSpProvider - unallocated SP: ${characterSkills.unallocatedSp ?? 0}');
    return characterSkills.unallocatedSp;
  } catch (e, stack) {
    Log.e('SKILLS', 'unallocatedSpProvider - failed to fetch', e, stack);
    return null;
  }
});

/// Provider for looking up trained level of a specific skill.
///
/// Takes (characterId, skillId) tuple. Returns 0 if skill not trained.
final trainedSkillLevelProvider = FutureProvider.family<int, (int, int)>((ref, ids) async {
  final (characterId, skillId) = ids;
  Log.d('SKILLS', 'trainedSkillLevelProvider - checking skill $skillId for character $characterId');

  final repository = ref.read(skillRepositoryProvider);
  final level = await repository.getTrainedLevel(characterId, skillId);
  Log.d('SKILLS', 'trainedSkillLevelProvider - skill $skillId: level $level');
  return level;
});

/// Provider for refreshing trained skills from ESI.
final refreshCharacterSkillsProvider =
    FutureProvider.family<void, int>((ref, characterId) async {
  Log.i('SKILLS', 'refreshCharacterSkillsProvider - invoked for character $characterId');
  final repository = ref.read(skillRepositoryProvider);
  await repository.refreshCharacterSkills(characterId);
});
