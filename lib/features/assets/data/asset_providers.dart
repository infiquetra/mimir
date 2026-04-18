import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import 'asset_repository.dart';

/// Provider for the currently selected location in the asset browser.
final selectedLocationProvider = StateProvider<int?>((ref) => null);

/// Provider for current market prices from ESI.
final marketPricesProvider = FutureProvider<Map<int, double>>((ref) async {
  final esiClient = ref.watch(esiClientProvider);
  final prices = await esiClient.getMarketPrices();
  return {
    for (final p in prices) p.typeId: p.averagePrice ?? p.adjustedPrice ?? 0.0
  };
});

/// Provider for raw asset list of a character.
final assetsProvider =
    StreamProvider.family<List<Asset>, int>((ref, characterId) {
  final repository = ref.watch(assetRepositoryProvider);
  return repository.watchAssets(characterId);
});

/// Provider for total asset value of a character.
final totalAssetValueProvider =
    FutureProvider.family<double, int>((ref, characterId) async {
  final assets = await ref.watch(assetsProvider(characterId).future);
  final pricesAsync = ref.watch(marketPricesProvider);

  return pricesAsync.when(
    data: (priceMap) {
      double total = 0;
      for (final asset in assets) {
        final price = priceMap[asset.typeId] ?? 0.0;
        total += price * asset.quantity;
      }
      return total;
    },
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Hierarchical model for asset location tree.
class AssetNode {
  final int locationId;
  final String name;
  final String type;
  final List<Asset> items;
  final List<AssetNode> children;
  final double totalValue;

  AssetNode({
    required this.locationId,
    required this.name,
    required this.type,
    required this.items,
    required this.children,
    required this.totalValue,
  });
}

/// Provider for assets grouped by location (hierarchical).
final assetsByLocationProvider =
    FutureProvider.family<List<AssetNode>, int>((ref, characterId) async {
  final assets = await ref.watch(assetsProvider(characterId).future);
  final priceMap = await ref.watch(marketPricesProvider.future);
  final database = ref.watch(databaseProvider);

  // Group assets by locationId.
  final grouped = <int, List<Asset>>{};
  for (final asset in assets) {
    grouped.putIfAbsent(asset.locationId, () => []).add(asset);
  }

  // Build the tree.
  // This is a complex operation that should probably be optimized.
  // For now, simpler grouping.
  final nodes = <AssetNode>[];

  for (final entry in grouped.entries) {
    final locationId = entry.key;
    final items = entry.value;

    // Attempt to get location name.
    final location = await database.getAssetLocation(locationId);
    final name = location?.locationName ?? 'Location #$locationId';
    final type = location?.locationType ?? 'unknown';

    double value = 0;
    for (final item in items) {
      value += (priceMap[item.typeId] ?? 0.0) * item.quantity;
    }

    nodes.add(AssetNode(
      locationId: locationId,
      name: name,
      type: type,
      items: items,
      children: [], // Handle nesting in next iteration
      totalValue: value,
    ));
  }

  return nodes;
});
