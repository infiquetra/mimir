import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../../characters/data/character_providers.dart';
import 'asset_repository.dart';
import 'asset_sync_service.dart';

/// Provider for the list of assets for the active character.
final assetsProvider = StreamProvider<List<Asset>>((ref) {
  final activeCharacter = ref.watch(activeCharacterProvider).value;
  if (activeCharacter == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(assetRepositoryProvider);
  return repository.watchAssets(activeCharacter.characterId);
});

/// Aggregated asset summary for a location.
class LocationAssetSummary {
  final AssetLocation location;
  final List<Asset> assets;
  final int itemCount;
  final double totalValue;

  LocationAssetSummary({
    required this.location,
    required this.assets,
    required this.itemCount,
    this.totalValue = 0.0,
  });
}

/// Provider for assets grouped by location.
final groupedAssetsProvider = FutureProvider<List<LocationAssetSummary>>((ref) async {
  final assets = await ref.watch(assetsProvider.future);
  final repository = ref.watch(assetRepositoryProvider);
  
  final grouped = <int, List<Asset>>{};
  for (final asset in assets) {
    grouped.putIfAbsent(asset.locationId, () => []).add(asset);
  }

  final summaries = <LocationAssetSummary>[];
  for (final entry in grouped.entries) {
    final locationId = entry.key;
    final items = entry.value;
    
    final location = await repository.getLocation(locationId) ?? AssetLocation(
      locationId: locationId,
      locationType: 'unknown',
      locationName: 'Location #$locationId',
      lastResolved: DateTime.now(),
    );

    summaries.add(LocationAssetSummary(
      location: location,
      assets: items,
      itemCount: items.fold(0, (sum, a) => sum + a.quantity),
    ));
  }

  summaries.sort((a, b) => b.itemCount.compareTo(a.itemCount));
  return summaries;
});

/// Provider for the asset sync state.
final assetSyncProvider = AsyncNotifierProvider<AssetSyncNotifier, void>(() {
  return AssetSyncNotifier();
});

class AssetSyncNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() => null;

  Future<void> sync() async {
    final activeCharacter = ref.read(activeCharacterProvider).value;
    if (activeCharacter == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final syncService = ref.read(assetSyncServiceProvider);
      await syncService.syncAssets(activeCharacter.characterId);
      
      ref.invalidate(assetsProvider);
      ref.invalidate(groupedAssetsProvider);
    });
  }
}
