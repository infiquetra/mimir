import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import '../../characters/data/character_status_providers.dart';
import '../../characters/data/character_status_repository.dart';
import 'asset_repository.dart';

/// Service for synchronizing character assets from ESI.
class AssetSyncService {
  final EsiClient _esiClient;
  final AssetRepository _repository;
  final CharacterStatusRepository _statusRepo;

  AssetSyncService({
    required EsiClient esiClient,
    required AssetRepository repository,
    required CharacterStatusRepository statusRepo,
  })  : _esiClient = esiClient,
        _repository = repository,
        _statusRepo = statusRepo;

  /// Performs a full asset synchronization for the character.
  Future<void> syncAssets(int characterId) async {
    Log.d('ASSETS.SYNC', 'syncAssets($characterId) - START');
    try {
      final allEsiAssets = <AssetItem>[];
      int page = 1;
      int? totalPages;

      // 1. Fetch all assets (paginated)
      do {
        final response = await _esiClient.getCharacterAssets(characterId, page: page);
        allEsiAssets.addAll(response.data);
        
        totalPages ??= int.tryParse(response.headers['x-pages']?.first ?? '1');
        Log.d('ASSETS.SYNC', 'Fetched page $page of $totalPages (${allEsiAssets.length} total)');
        page++;
      } while (totalPages != null && page <= totalPages);

      Log.i('ASSETS.SYNC', 'Total assets fetched from ESI: ${allEsiAssets.length}');

      // 2. Identify locations that need resolution
      final locationIds = allEsiAssets.map((a) => a.locationId).toSet();
      await _resolveLocations(characterId, locationIds.toList());

      // 3. Resolve custom names for singletons (ships, containers)
      final singletonItemIds = allEsiAssets
          .where((a) => a.isSingleton)
          .map((a) => a.itemId)
          .toList();
      final customNames = await _resolveCustomNames(characterId, singletonItemIds);

      // 4. Resolve type names (from ESI names endpoint)
      final typeIds = allEsiAssets.map((a) => a.typeId).toSet();
      final typeNameMap = await _resolveTypeNames(typeIds.toList());

      // 5. Convert to companions and save
      final companions = allEsiAssets.map((asset) {
        return AssetsCompanion.insert(
          itemId: asset.itemId,
          characterId: characterId,
          typeId: asset.typeId,
          locationId: asset.locationId,
          locationFlag: asset.locationFlag,
          quantity: asset.quantity,
          isSingleton: asset.isSingleton,
          typeName: typeNameMap[asset.typeId] ?? 'Unknown Type',
          customName: Value(customNames[asset.itemId]),
          containedInId: const Value(null), // Will implement container hierarchy in Phase 2
        );
      }).toList();

      await _repository.replaceAllAssets(characterId, companions);
      Log.d('ASSETS.SYNC', 'syncAssets($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('ASSETS.SYNC', 'syncAssets($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  Future<void> _resolveLocations(int characterId, List<int> locationIds) async {
    final missingIds = <int>[];
    for (final id in locationIds) {
      final cached = await _repository.getLocation(id);
      if (cached == null || cached.lastResolved.isBefore(DateTime.now().subtract(const Duration(days: 7)))) {
        missingIds.add(id);
      }
    }

    if (missingIds.isEmpty) return;

    Log.d('ASSETS.SYNC', 'Resolving ${missingIds.length} missing/stale locations');

    // Split into stations (NPC) and structures (Player)
    final stationIds = missingIds.where((id) => id >= 60000000 && id < 64000000).toList();
    final structureIds = missingIds.where((id) => id >= 1000000000000).toList();

    final locationCompanions = <AssetLocationsCompanion>[];

    // Resolve stations via ESI names endpoint
    if (stationIds.isNotEmpty) {
      final names = await _statusRepo.resolveNames(stationIds);
      for (final n in names) {
        locationCompanions.add(AssetLocationsCompanion.insert(
          locationId: Value(n.id),
          locationType: 'station',
          locationName: n.name,
          lastResolved: DateTime.now(),
        ));
      }
    }

    // Resolve structures via ESI structure endpoint (requires character auth)
    if (structureIds.isNotEmpty) {
      final structureNames = await _statusRepo.resolveStructureNames(structureIds, characterId);
      for (final entry in structureNames.entries) {
        locationCompanions.add(AssetLocationsCompanion.insert(
          locationId: Value(entry.key),
          locationType: 'structure',
          locationName: entry.value,
          lastResolved: DateTime.now(),
        ));
      }
    }

    if (locationCompanions.isNotEmpty) {
      await _repository.upsertLocations(locationCompanions);
    }
  }

  Future<Map<int, String>> _resolveCustomNames(int characterId, List<int> itemIds) async {
    final result = <int, String>{};
    if (itemIds.isEmpty) return result;

    // Fetch in batches of 1000 (ESI limit)
    for (var i = 0; i < itemIds.length; i += 1000) {
      final end = (i + 1000 < itemIds.length) ? i + 1000 : itemIds.length;
      final batch = itemIds.sublist(i, end);
      try {
        final names = await _esiClient.getCharacterAssetNames(characterId, batch);
        for (final n in names) {
          result[n.itemId] = n.name;
        }
      } catch (e) {
        Log.w('ASSETS.SYNC', 'Failed to resolve batch of custom names: $e');
      }
    }
    return result;
  }

  Future<Map<int, String>> _resolveTypeNames(List<int> typeIds) async {
    final result = <int, String>{};
    
    Log.d('ASSETS.SYNC', 'Resolving ${typeIds.length} type names from ESI');
    final names = await _statusRepo.resolveNames(typeIds);
    for (final n in names) {
      result[n.id] = n.name;
    }

    return result;
  }
}

/// Provider for the asset sync service.
final assetSyncServiceProvider = Provider<AssetSyncService>((ref) {
  return AssetSyncService(
    esiClient: ref.watch(esiClientProvider),
    repository: ref.watch(assetRepositoryProvider),
    statusRepo: ref.watch(characterStatusRepositoryProvider),
  );
});
