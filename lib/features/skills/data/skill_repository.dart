import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';

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
      final characters = await _database.getAllCharacters();
      Log.i('SKILLS', 'getAllCharacterQueues - loading queues for ${characters.length} characters');
      final queueMap = <int, List<SkillQueueEntry>>{};

      for (final character in characters) {
        final queue = await _database.getSkillQueue(character.characterId);
        queueMap[character.characterId] = queue;
        Log.d('SKILLS', 'getAllCharacterQueues - character ${character.characterId}: ${queue.length} items');
      }

      Log.i('SKILLS', 'getAllCharacterQueues - loaded queues for ${queueMap.length} characters');
      Log.d('SKILLS', 'getAllCharacterQueues() - SUCCESS');
      return queueMap;
    } catch (e, stack) {
      Log.e('SKILLS', 'getAllCharacterQueues() - FAILED', e, stack);
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
