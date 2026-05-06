import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';

/// Repository for managing character assets.
class AssetRepository {
  final AppDatabase _database;

  AssetRepository({
    required AppDatabase database,
  }) : _database = database;

  /// Replaces all assets for a character in the local database.
  Future<void> replaceAllAssets(
    int characterId,
    List<AssetsCompanion> assets,
  ) async {
    Log.d('ASSETS', 'replaceAllAssets($characterId) - saving ${assets.length} items');
    
    try {
      await _database.transaction(() async {
        // 1. Delete old assets
        await (_database.delete(_database.assets)
              ..where((a) => a.characterId.equals(characterId)))
            .go();

        // 2. Insert new assets in batches
        await _database.batch((batch) {
          batch.insertAll(
            _database.assets,
            assets,
            mode: InsertMode.insertOrReplace,
          );
        });
      });
      
      Log.d('ASSETS', 'replaceAllAssets($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('ASSETS', 'replaceAllAssets($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Upserts location information into the local cache.
  Future<void> upsertLocations(List<AssetLocationsCompanion> locations) async {
    Log.d('ASSETS', 'upsertLocations - saving ${locations.length} locations');
    try {
      await _database.batch((batch) {
        batch.insertAll(
          _database.assetLocations,
          locations,
          mode: InsertMode.insertOrReplace,
        );
      });
    } catch (e, stack) {
      Log.e('ASSETS', 'upsertLocations - FAILED', e, stack);
    }
  }

  /// Watches all assets for a character.
  Stream<List<Asset>> watchAssets(int characterId) {
    return (_database.select(_database.assets)
          ..where((a) => a.characterId.equals(characterId)))
        .watch();
  }

  /// Watches assets grouped by location.
  /// 
  /// This returns a stream of location IDs and their assets.
  Stream<Map<int, List<Asset>>> watchAssetsByLocation(int characterId) {
    return watchAssets(characterId).map((assets) {
      final grouped = <int, List<Asset>>{};
      for (final asset in assets) {
        grouped.putIfAbsent(asset.locationId, () => []).add(asset);
      }
      return grouped;
    });
  }

  /// Gets a cached location by ID.
  Future<AssetLocation?> getLocation(int locationId) {
    return (_database.select(_database.assetLocations)
          ..where((l) => l.locationId.equals(locationId)))
        .getSingleOrNull();
  }

  /// Gets all cached locations.
  Future<List<AssetLocation>> getAllLocations() {
    return _database.select(_database.assetLocations).get();
  }
}

/// Provider for the asset repository.
final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepository(
    database: ref.watch(databaseProvider),
  );
});
