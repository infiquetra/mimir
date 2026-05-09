import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/esi_client.dart';
import '../../../core/logging/logger.dart';
import 'market_repository.dart';

/// Service for synchronizing Market data from ESI.
class MarketSyncService {
  final EsiClient _esiClient;
  final MarketRepository _repository;

  MarketSyncService(this._esiClient, this._repository);

  /// Fetch and store all active orders for a character.
  Future<void> syncOrders(int characterId) async {
    Log.d('MARKET.SYNC', 'syncOrders($characterId) - START');
    try {
      final response = await _esiClient.getCharacterOrders(characterId);
      final orders = response.data;
      Log.i('MARKET.SYNC', 'Total active orders fetched from ESI: ${orders.length}');

      final companions = orders.map((order) => MarketOrdersCompanion(
        orderId: Value(order.orderId),
        characterId: Value(characterId),
        typeId: Value(order.typeId),
        regionId: Value(order.regionId),
        locationId: Value(order.locationId),
        price: Value(order.price),
        volumeRemain: Value(order.volumeRemain),
        volumeTotal: Value(order.volumeTotal),
        minVolume: Value(order.minVolume),
        isBuyOrder: Value(order.isBuyOrder),
        issued: Value(order.issued),
        duration: Value(order.duration),
        range: Value(order.range),
        isCorporation: Value(order.isCorporation),
        escrow: Value(order.escrow),
        state: Value(order.state),
      )).toList();

      await _repository.replaceAllOrders(characterId, companions);
      Log.d('MARKET.SYNC', 'syncOrders($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('MARKET.SYNC', 'syncOrders($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Fetch and store all market prices.
  Future<void> syncPrices() async {
    Log.d('MARKET.SYNC', 'syncPrices - START');
    try {
      final response = await _esiClient.getMarketPrices();
      final prices = response.data;
      Log.i('MARKET.SYNC', 'Total prices fetched from ESI: ${prices.length}');

      final now = DateTime.now();
      final companions = prices.map((price) => MarketPricesCompanion(
        typeId: Value(price.typeId),
        adjustedPrice: Value(price.adjustedPrice),
        averagePrice: Value(price.averagePrice),
        lastUpdated: Value(now),
      )).toList();

      await _repository.replaceAllPrices(companions);
      Log.d('MARKET.SYNC', 'syncPrices - SUCCESS');
    } catch (e, stack) {
      Log.e('MARKET.SYNC', 'syncPrices - FAILED', e, stack);
      rethrow;
    }
  }
}

/// Provider for the [MarketSyncService].
final marketSyncServiceProvider = Provider<MarketSyncService>((ref) {
  return MarketSyncService(
    ref.watch(esiClientProvider),
    ref.watch(marketRepositoryProvider),
  );
});
