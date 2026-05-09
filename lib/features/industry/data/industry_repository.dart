import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';

/// Repository for managing Industry data (Blueprints and Jobs).
class IndustryRepository {
  final AppDatabase _database;

  IndustryRepository(this._database);

  // --- Blueprints ---

  /// Watch all blueprints for a character.
  Stream<List<Blueprint>> watchBlueprints(int characterId) {
    return (_database.select(_database.blueprints)
          ..where((b) => b.characterId.equals(characterId)))
        .watch();
  }

  /// Replace all blueprints for a character.
  Future<void> replaceAllBlueprints(int characterId, List<BlueprintsCompanion> items) async {
    Log.d('INDUSTRY', 'replaceAllBlueprints($characterId) - saving ${items.length} items');
    await _database.transaction(() async {
      await (_database.delete(_database.blueprints)
            ..where((b) => b.characterId.equals(characterId)))
          .go();
      await _database.batch((batch) {
        batch.insertAll(_database.blueprints, items);
      });
    });
    Log.i('INDUSTRY', 'replaceAllBlueprints($characterId) - SUCCESS');
  }

  // --- Industry Jobs ---

  /// Watch all industry jobs for a character.
  Stream<List<IndustryJob>> watchIndustryJobs(int characterId, {bool includeCompleted = false}) {
    final query = _database.select(_database.industryJobs)
      ..where((j) => j.characterId.equals(characterId));

    if (!includeCompleted) {
      query.where((j) =>
          j.status.equals('active') | j.status.equals('paused') | j.status.equals('ready'));
    }

    return (query..orderBy([(j) => OrderingTerm.desc(j.endDate)])).watch();
  }

  /// Replace all industry jobs for a character.
  Future<void> replaceAllIndustryJobs(int characterId, List<IndustryJobsCompanion> jobs) async {
    Log.d('INDUSTRY', 'replaceAllIndustryJobs($characterId) - saving ${jobs.length} jobs');
    await _database.transaction(() async {
      await (_database.delete(_database.industryJobs)
            ..where((j) => j.characterId.equals(characterId)))
          .go();
      await _database.batch((batch) {
        batch.insertAll(_database.industryJobs, jobs);
      });
    });
    Log.i('INDUSTRY', 'replaceAllIndustryJobs($characterId) - SUCCESS');
  }
}

/// Provider for the [IndustryRepository].
final industryRepositoryProvider = Provider<IndustryRepository>((ref) {
  return IndustryRepository(ref.watch(databaseProvider));
});
