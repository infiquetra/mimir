import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
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
    try {
      // Fetch skill queue from ESI.
      final queueItems = await _esiClient.getSkillQueue(characterId);

      // Convert ESI items to database companions.
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
      await _database.replaceSkillQueue(characterId, companions);

      debugPrint(
          'Skill queue refreshed for character $characterId: ${companions.length} items');
    } catch (e) {
      debugPrint('Failed to refresh skill queue for $characterId: $e');
      rethrow;
    }
  }

  /// Gets the skill queue from the local database.
  Future<List<SkillQueueEntry>> getSkillQueue(int characterId) {
    return _database.getSkillQueue(characterId);
  }

  /// Watches the skill queue for reactive updates.
  Stream<List<SkillQueueEntry>> watchSkillQueue(int characterId) {
    return _database.watchSkillQueue(characterId);
  }
}

/// Provider for the skill repository.
final skillRepositoryProvider = Provider<SkillRepository>((ref) {
  return SkillRepository(
    database: ref.watch(databaseProvider),
    esiClient: ref.watch(esiClientProvider),
  );
});
