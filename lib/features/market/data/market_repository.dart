import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';

/// Repository for managing Market data (Orders and Prices).
class MarketRepository {
  final AppDatabase _database;

  MarketRepository(this._database);

  // --- Market Orders ---

  /// Watch all active orders for a character.
  Stream<List<MarketOrder>> watchActiveOrders(int characterId) {
    return (_database.select(_database.marketOrders)
          ..where((o) => o.characterId.equals(characterId))
          ..orderBy([(o) => OrderingTerm.desc(o.issued)]))
        .watch();
  }

  /// Replace all active orders for a character.
  Future<void> replaceAllOrders(int characterId, List<MarketOrdersCompanion> orders) async {
    Log.d('MARKET', 'replaceAllOrders($characterId) - saving ${orders.length} orders');
    await _database.transaction(() async {
      await (_database.delete(_database.marketOrders)
            ..where((o) => o.characterId.equals(characterId)))
          .go();
      await _database.batch((batch) {
        batch.insertAll(_database.marketOrders, orders);
      });
    });
    Log.i('MARKET', 'replaceAllOrders($characterId) - SUCCESS');
  }

  // --- Market Prices ---

  /// Watch a specific market price.
  Stream<MarketPrice?> watchPrice(int typeId) {
    return (_database.select(_database.marketPrices)
          ..where((p) => p.typeId.equals(typeId)))
        .watchSingleOrNull();
  }
  
  /// Get a specific market price asynchronously.
  Future<MarketPrice?> getPrice(int typeId) {
    return (_database.select(_database.marketPrices)
          ..where((p) => p.typeId.equals(typeId)))
        .getSingleOrNull();
  }

  /// Replace all market prices.
  Future<void> replaceAllPrices(List<MarketPricesCompanion> prices) async {
    Log.d('MARKET', 'replaceAllPrices - saving ${prices.length} prices');
    await _database.transaction(() async {
      await _database.delete(_database.marketPrices).go();
      await _database.batch((batch) {
        batch.insertAll(_database.marketPrices, prices);
      });
    });
    Log.i('MARKET', 'replaceAllPrices - SUCCESS');
  }
}

/// Provider for the [MarketRepository].
final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MarketRepository(ref.watch(databaseProvider));
});
