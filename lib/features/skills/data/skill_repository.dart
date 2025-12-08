import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import '../../../core/sde/sde_providers.dart';
import '../domain/skill_prerequisite_service.dart';

/// Repository for managing skill queue data.
///
/// Coordinates between:
/// - ESI client for fetching fresh skill queue data
/// - Local database for caching and offline access
class SkillRepository {
  final AppDatabase _database;
  final EsiClient _esiClient;

  SkillRepository({
    required AppDatabase database,
    required EsiClient esiClient,
  })  : _database = database,
        _esiClient = esiClient;

  /// Refreshes the skill queue from ESI and saves to database.
  Future<void> refreshSkillQueue(int characterId) async {
    Log.d('SKILLS', 'refreshSkillQueue($characterId) - START');
    try {
      // Fetch skill queue from ESI.
      Log.d('SKILLS', 'refreshSkillQueue - fetching from ESI');
      final queueItems = await _esiClient.getSkillQueue(characterId);
      Log.i('SKILLS', 'refreshSkillQueue - fetched ${queueItems.length} queue items from ESI');

      // Convert ESI items to database companions.
      Log.d('SKILLS', 'refreshSkillQueue - converting to database companions');
      final companions = queueItems.map((item) {
        return SkillQueueEntriesCompanion.insert(
          characterId: characterId,
          queuePosition: item.queuePosition,
          skillId: item.skillId,
          finishedLevel: item.finishedLevel,
          startDate: Value(item.startDate),
          finishDate: Value(item.finishDate),
          trainingStartSp: Value(item.trainingStartSp),
          levelEndSp: Value(item.levelEndSp),
          levelStartSp: Value(item.levelStartSp),
        );
      }).toList();

      // Replace the skill queue in the database.
      Log.d('SKILLS', 'refreshSkillQueue - saving to database');
      await _database.replaceSkillQueue(characterId, companions);
      Log.i('SKILLS', 'refreshSkillQueue - saved ${companions.length} queue items to database');
      Log.d('SKILLS', 'refreshSkillQueue($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('SKILLS', 'refreshSkillQueue($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Gets the skill queue from the local database.
  Future<List<SkillQueueEntry>> getSkillQueue(int characterId) async {
    Log.d('SKILLS', 'getSkillQueue($characterId) - START');
    try {
      final queue = await _database.getSkillQueue(characterId);
      Log.i('SKILLS', 'getSkillQueue - found ${queue.length} queue items');
      Log.d('SKILLS', 'getSkillQueue($characterId) - SUCCESS');
      return queue;
    } catch (e, stack) {
      Log.e('SKILLS', 'getSkillQueue($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Watches the skill queue for reactive updates.
  Stream<List<SkillQueueEntry>> watchSkillQueue(int characterId) {
    Log.d('SKILLS', 'watchSkillQueue($characterId) - subscribed to stream');
    return _database.watchSkillQueue(characterId);
  }

  /// Gets skill queues for all characters.
  ///
  /// Returns a map of characterId → skill queue entries for all characters
  /// that have queue entries. Characters with empty queues are included
  /// with empty lists.
  Future<Map<int, List<SkillQueueEntry>>> getAllCharacterQueues() async {
    Log.d('SKILLS', 'getAllCharacterQueues() - START');
    try {
      // Get all characters first to include those with empty queues.
      final characters = await _database.getAllCharacters();
      Log.i('SKILLS', 'getAllCharacterQueues - loading queues for ${characters.length} characters');

      // Use batch query to get all queues in a single database call.
      // This avoids N+1 query problem (N queries for N characters).
      final allQueues = await _database.getAllSkillQueues();

      // Ensure all characters are in the map (even with empty queues).
      final queueMap = <int, List<SkillQueueEntry>>{};
      for (final character in characters) {
        queueMap[character.characterId] = allQueues[character.characterId] ?? [];
        Log.d('SKILLS', 'getAllCharacterQueues - character ${character.characterId}: ${queueMap[character.characterId]!.length} items');
      }

      Log.i('SKILLS', 'getAllCharacterQueues - loaded queues for ${queueMap.length} characters in single query');
      Log.d('SKILLS', 'getAllCharacterQueues() - SUCCESS');
      return queueMap;
    } catch (e, stack) {
      Log.e('SKILLS', 'getAllCharacterQueues() - FAILED', e, stack);
      rethrow;
    }
  }

  /// Refreshes trained skills from ESI and saves to database.
  ///
  /// Fetches the complete skill list for a character including trained
  /// levels and skill points. Updates the local cache atomically.
  Future<void> refreshCharacterSkills(int characterId) async {
    Log.d('SKILLS', 'refreshCharacterSkills($characterId) - START');
    try {
      // Fetch character skills from ESI.
      Log.d('SKILLS', 'refreshCharacterSkills - fetching from ESI');
      final characterSkills = await _esiClient.getSkills(characterId);
      Log.i('SKILLS', 'refreshCharacterSkills - fetched ${characterSkills.skills.length} trained skills from ESI');
      Log.i('SKILLS', 'refreshCharacterSkills - total SP: ${characterSkills.totalSp}, unallocated: ${characterSkills.unallocatedSp ?? 0}');

      // Convert ESI skills to database companions.
      Log.d('SKILLS', 'refreshCharacterSkills - converting to database companions');
      final now = DateTime.now();
      final companions = characterSkills.skills.map((skill) {
        return CharacterSkillsCompanion.insert(
          characterId: characterId,
          skillId: skill.skillId,
          trainedSkillLevel: skill.trainedSkillLevel,
          activeSkillLevel: skill.activeSkillLevel,
          skillpointsInSkill: skill.skillpointsInSkill,
          lastUpdated: now,
        );
      }).toList();

      // Replace trained skills in the database.
      Log.d('SKILLS', 'refreshCharacterSkills - saving to database');
      await _database.replaceCharacterSkills(characterId, companions);
      Log.i('SKILLS', 'refreshCharacterSkills - saved ${companions.length} trained skills to database');
      Log.d('SKILLS', 'refreshCharacterSkills($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('SKILLS', 'refreshCharacterSkills($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Gets trained skills from the local database.
  Future<List<CharacterSkill>> getCharacterSkills(int characterId) async {
    Log.d('SKILLS', 'getCharacterSkills($characterId) - START');
    try {
      final skills = await _database.getCharacterSkills(characterId);
      Log.i('SKILLS', 'getCharacterSkills - found ${skills.length} trained skills');
      Log.d('SKILLS', 'getCharacterSkills($characterId) - SUCCESS');
      return skills;
    } catch (e, stack) {
      Log.e('SKILLS', 'getCharacterSkills($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Watches trained skills for reactive updates.
  Stream<List<CharacterSkill>> watchCharacterSkills(int characterId) {
    Log.d('SKILLS', 'watchCharacterSkills($characterId) - subscribed to stream');
    return _database.watchCharacterSkills(characterId);
  }

  /// Gets the trained level for a specific skill.
  ///
  /// Returns 0 if the skill is not trained (no entry in database).
  Future<int> getTrainedLevel(int characterId, int skillId) async {
    Log.d('SKILLS', 'getTrainedLevel($characterId, $skillId) - START');
    try {
      final skill = await _database.getCharacterSkill(characterId, skillId);
      final level = skill?.trainedSkillLevel ?? 0;
      Log.d('SKILLS', 'getTrainedLevel - skillId $skillId: level $level');
      return level;
    } catch (e, stack) {
      Log.e('SKILLS', 'getTrainedLevel($characterId, $skillId) - FAILED', e, stack);
      rethrow;
    }
  }
}

/// Provider for the skill repository.
final skillRepositoryProvider = Provider<SkillRepository>((ref) {
  return SkillRepository(
    database: ref.watch(databaseProvider),
    esiClient: ref.watch(esiClientProvider),
  );
});

/// Provider for the skill prerequisite service.
final skillPrerequisiteServiceProvider = Provider<SkillPrerequisiteService>((ref) {
  return SkillPrerequisiteService(
    sdeService: ref.watch(sdeServiceProvider),
    skillRepository: ref.watch(skillRepositoryProvider),
  );
});
