import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';

/// Repository for managing Planetary Industry (PI) data.
class PlanetaryRepository {
  final AppDatabase _database;

  PlanetaryRepository({
    required AppDatabase database,
  }) : _database = database;

  /// Saves a list of colonies and their pins to the database.
  Future<void> saveColonies(
    int characterId,
    List<PlanetaryColoniesCompanion> colonies,
    List<PlanetaryPinsCompanion> pins,
  ) async {
    Log.d('PI.DB', 'saveColonies($characterId) - saving ${colonies.length} colonies and ${pins.length} pins');
    
    try {
      await _database.batch((batch) {
        // 1. Upsert colonies
        batch.insertAll(
          _database.planetaryColonies,
          colonies,
          mode: InsertMode.insertOrReplace,
        );

        // 2. Upsert pins
        batch.insertAll(
          _database.planetaryPins,
          pins,
          mode: InsertMode.insertOrReplace,
        );
      });
      
      Log.d('PI.DB', 'saveColonies($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('PI.DB', 'saveColonies($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Watches colonies for a character.
  Stream<List<PlanetaryColony>> watchColonies(int characterId) {
    Log.d('PI.DB', 'watchColonies($characterId) - subscribed to stream');
    return (_database.select(_database.planetaryColonies)
          ..where((c) => c.characterId.equals(characterId))
          ..orderBy([(c) => OrderingTerm.asc(c.planetName)]))
        .watch();
  }

  /// Watches all colonies across all characters.
  Stream<List<PlanetaryColony>> watchAllColonies() {
    Log.d('PI.DB', 'watchAllColonies() - subscribed to stream');
    return (_database.select(_database.planetaryColonies)
          ..orderBy([(c) => OrderingTerm.asc(c.planetName)]))
        .watch();
  }

  /// Watches pins for a specific planet.
  Stream<List<PlanetaryPin>> watchPins(int characterId, int planetId) {
    Log.d('PI.DB', 'watchPins($characterId, $planetId) - subscribed to stream');
    return (_database.select(_database.planetaryPins)
          ..where((p) => p.characterId.equals(characterId) & p.planetId.equals(planetId)))
        .watch();
  }

  /// Gets all colonies for a character.
  Future<List<PlanetaryColony>> getColonies(int characterId) {
    return (_database.select(_database.planetaryColonies)
          ..where((c) => c.characterId.equals(characterId)))
        .get();
  }
}

/// Provider for the planetary repository.
final planetaryRepositoryProvider = Provider<PlanetaryRepository>((ref) {
  return PlanetaryRepository(
    database: ref.watch(databaseProvider),
  );
});
