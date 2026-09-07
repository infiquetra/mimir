import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart' hide MarketHistoryEntry;
import '../../../core/sde/sde_providers.dart';
import '../../characters/data/character_providers.dart';
import 'market_repository.dart';
import 'market_sync_service.dart';

// --- Constants ---

/// Default region: The Forge (Jita hub).
const int kDefaultRegionId = 10000002;

/// Major trade hub regions.
const Map<int, String> kTradeHubRegions = {
  10000002: 'The Forge (Jita)',
  10000043: 'Domain (Amarr)',
  10000032: 'Sinq Laison (Dodixie)',
  10000042: 'Metropolis (Hek)',
  10000030: 'Heimatar (Rens)',
};

// --- Sync Providers ---

/// Provider to trigger a manual sync of all market data for a character.
final syncMarketProvider = FutureProvider.autoDispose<void>((ref) async {
  final activeCharacter = await ref.watch(activeCharacterProvider.future);
  if (activeCharacter == null) return;

  final syncService = ref.read(marketSyncServiceProvider);

  // Run both syncs in parallel
  await Future.wait([
    syncService.syncOrders(activeCharacter.characterId),
    syncService.syncPrices(),
  ]);
});

// --- Orders ---

/// Stream of all active orders for the active character.
final activeCharacterOrdersProvider = StreamProvider<List<MarketOrder>>((
  ref,
) async* {
  final activeCharacter = await ref.watch(activeCharacterProvider.future);
  if (activeCharacter == null) {
    yield [];
    return;
  }

  final repository = ref.watch(marketRepositoryProvider);
  yield* repository.watchActiveOrders(activeCharacter.characterId);
});

// --- Prices ---

/// Provider for a specific item's market price.
final itemPriceProvider = StreamProvider.family<MarketPrice?, int>((
  ref,
  typeId,
) {
  final repository = ref.watch(marketRepositoryProvider);
  return repository.watchPrice(typeId);
});

/// Future provider for a specific item's market price.
final itemPriceFutureProvider = FutureProvider.family<MarketPrice?, int>((
  ref,
  typeId,
) {
  final repository = ref.watch(marketRepositoryProvider);
  return repository.getPrice(typeId);
});

// --- Market History ---

/// Provider for market history (price chart data).
/// Fetches from DB; if empty or stale, syncs from ESI first.
final marketHistoryProvider = FutureProvider.autoDispose
    .family<List<MarketHistoryEntry>, ({int typeId, int regionId})>((
      ref,
      params,
    ) async {
      final repository = ref.watch(marketRepositoryProvider);
      final syncService = ref.watch(marketSyncServiceProvider);

      // Check if we have cached data
      var history = await repository.getMarketHistory(
        params.typeId,
        params.regionId,
      );

      // If no data or data is older than 24 hours, fetch fresh
      if (history.isEmpty) {
        await syncService.syncMarketHistory(params.typeId, params.regionId);
        history = await repository.getMarketHistory(
          params.typeId,
          params.regionId,
        );
      }

      return history;
    });

// --- Search ---

/// Currently selected region ID for market browsing.
final selectedRegionProvider = StateProvider<int>((ref) => kDefaultRegionId);

/// Search results: bundled SDE substring match first (offline and instant),
/// augmented by an exact-name lookup against ESI `POST /universe/ids/` so
/// items outside the bundled SDE (minerals, commodities, ...) still resolve
/// while online. The old `GET /search/` route was removed from ESI, which is
/// why this provider could never return a result.
final searchItemsProvider = FutureProvider.autoDispose
    .family<List<MarketItem>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.length < 3) return [];

      final sde = ref.watch(sdeServiceProvider);
      await sde.initialize();

      final byId = <int, MarketItem>{};
      for (final type in await sde.database.searchTypesByName(trimmed)) {
        byId[type.typeId] = MarketItem(
          typeId: type.typeId,
          name: type.typeName,
        );
      }

      // /universe/ids/ matches whole names only, so it can only add an exact
      // hit that the SDE substring search missed.
      try {
        final esiClient = ref.watch(esiClientProvider);
        final exact = await esiClient.resolveInventoryTypesByName([trimmed]);
        for (final name in exact) {
          byId.putIfAbsent(
            name.id,
            () => MarketItem(typeId: name.id, name: name.name),
          );
        }
      } catch (e) {
        // Offline or rate-limited: the local SDE results still stand.
        Log.w('MARKET', 'searchItems - ESI name lookup failed, SDE only: $e');
      }

      Log.i('MARKET', 'searchItems("$trimmed") - ${byId.length} results');
      return byId.values.toList()
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    });

/// Simple holder for a selected market item (typeId + name).
class MarketItem {
  final int typeId;
  final String name;
  const MarketItem({required this.typeId, required this.name});
}

/// Currently selected item for the market browser.
final selectedMarketItemProvider = StateProvider<MarketItem?>((ref) => null);
