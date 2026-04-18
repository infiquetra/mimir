import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';

/// Repository for managing character assets.
///
/// Coordinates between:
/// - ESI client for fetching full asset list and locations
/// - Local database for caching and offline hierarchical browsing
class AssetRepository {
  final AppDatabase _database;
  final EsiClient _esiClient;

  AssetRepository({
    required AppDatabase database,
    required EsiClient esiClient,
  })  : _database = database,
        _esiClient = esiClient;

  /// Refreshes all assets for a character from ESI.
  ///
  /// Handles pagination to fetch the complete asset list.
  Future<void> refreshAssets(int characterId) async {
    Log.d('ASSETS', 'refreshAssets($characterId) - START');
    try {
      final allAssets = <AssetItem>[];
      int page = 1;

      // Fetch all pages of assets.
      while (true) {
        Log.d('ASSETS', 'refreshAssets - fetching page $page');
        final pageAssets =
            await _esiClient.getCharacterAssets(characterId, page: page);
        if (pageAssets.isEmpty) break;
        allAssets.addAll(pageAssets);
        Log.d('ASSETS',
            'refreshAssets - fetched ${pageAssets.length} items from page $page');
        page++;
      }

      Log.i('ASSETS',
          'refreshAssets - fetched total ${allAssets.length} assets from ESI');

      // Convert to database companions.
      final companions = allAssets.map((item) {
        // Determine location type (basic heuristic, refined later during resolution)
        String locationType = 'item';
        if (item.locationId >= 60000000 && item.locationId < 61000000) {
          locationType = 'station';
        } else if (item.locationId >= 100000000) {
          locationType = 'structure';
        }

        return AssetsCompanion.insert(
          itemId: Value(item.itemId),
          characterId: characterId,
          typeId: item.typeId,
          locationId: item.locationId,
          locationType: locationType,
          locationFlag: item.locationFlag,
          quantity: item.quantity,
          isSingleton: item.isSingleton,
          lastUpdated: DateTime.now(),
        );
      }).toList();

      // Replace in database.
      await _database.replaceAssets(characterId, companions);
      Log.i('ASSETS',
          'refreshAssets - saved ${companions.length} assets to database');

      // Record a snapshot of total value after sync.
      await recordValueSnapshot(characterId);

      Log.d('ASSETS', 'refreshAssets($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('ASSETS', 'refreshAssets($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Resolves location names for assets.
  Future<void> resolveLocationNames(int characterId) async {
    Log.d('ASSETS', 'resolveLocationNames($characterId) - START');
    try {
      final assets = await _database.getAssetsList(characterId);
      final uniqueLocationIds = assets.map((a) => a.locationId).toSet();
      Log.d('ASSETS',
          'resolveLocationNames - unique locations to resolve: ${uniqueLocationIds.length}');

      // Filter out already resolved locations (optional optimization).
      final locationsToResolve = <int>[];
      for (final id in uniqueLocationIds) {
        final existing = await _database.getAssetLocation(id);
        if (existing == null || existing.locationName == null) {
          locationsToResolve.add(id);
        }
      }

      Log.i('ASSETS',
          'resolveLocationNames - resolving ${locationsToResolve.length} new locations');

      // Resolve in batches.
      for (int i = 0; i < locationsToResolve.length; i += 100) {
        final batch = locationsToResolve.sublist(
          i,
          (i + 100) > locationsToResolve.length
              ? locationsToResolve.length
              : i + 100,
        );

        // For now, resolve using /universe/names endpoint via EsiClient.
        final names = await _esiClient.getUniverseNames(batch);
        final companions = names.map((un) {
          return AssetLocationsCompanion.insert(
            locationId: Value(un.id),
            locationType: un.category,
            locationName: Value(un.name),
          );
        }).toList();

        await _database.upsertAssetLocations(companions);
        Log.d('ASSETS',
            'resolveLocationNames - saved batch of ${companions.length}');
      }

      Log.d('ASSETS', 'resolveLocationNames($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('ASSETS', 'resolveLocationNames($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Records a snapshot of the current total asset value.
  Future<void> recordValueSnapshot(int characterId) async {
    Log.d('ASSETS', 'recordValueSnapshot($characterId) - START');
    try {
      final assets = await _database.getAssetsList(characterId);
      final prices = await _esiClient.getMarketPrices();
      final priceMap = {
        for (final p in prices)
          p.typeId: p.averagePrice ?? p.adjustedPrice ?? 0.0
      };

      double totalValue = 0;
      for (final asset in assets) {
        final price = priceMap[asset.typeId] ?? 0.0;
        totalValue += price * asset.quantity;
      }

      Log.i('ASSETS', 'recordValueSnapshot - total value: $totalValue ISK');

      await _database.recordAssetSnapshot(AssetSnapshotsCompanion.insert(
        characterId: characterId,
        totalValue: totalValue,
        snapshotDate: DateTime.now(),
      ));

      Log.d('ASSETS', 'recordValueSnapshot($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('ASSETS', 'recordValueSnapshot($characterId) - FAILED', e, stack);
    }
  }

  /// Watches all assets for a character.
  Stream<List<Asset>> watchAssets(int characterId) {
    return _database.watchAssets(characterId);
  }

  /// Gets historical value snapshots.
  Future<List<AssetSnapshot>> getValueHistory(int characterId) {
    return _database.getAssetSnapshots(characterId);
  }
}

/// Provider for the asset repository.
final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepository(
    database: ref.watch(databaseProvider),
    esiClient: ref.watch(esiClientProvider),
  );
});
