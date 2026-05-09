import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../characters/data/character_providers.dart';
import 'market_repository.dart';
import 'market_sync_service.dart';

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
final activeCharacterOrdersProvider = StreamProvider<List<MarketOrder>>((ref) async* {
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
final itemPriceProvider = StreamProvider.family<MarketPrice?, int>((ref, typeId) {
  final repository = ref.watch(marketRepositoryProvider);
  return repository.watchPrice(typeId);
});

/// Future provider for a specific item's market price.
final itemPriceFutureProvider = FutureProvider.family<MarketPrice?, int>((ref, typeId) {
  final repository = ref.watch(marketRepositoryProvider);
  return repository.getPrice(typeId);
});
