import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/market/data/market_repository.dart';

void main() {
  late AppDatabase database;
  late MarketRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = MarketRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('MarketRepository', () {
    const characterId = 12345;

    test('watchActiveOrders returns orders for character', () async {
      // Insert test data
      final companions = [
        MarketOrdersCompanion.insert(
          orderId: const Value(1000),
          characterId: characterId,
          typeId: 34,
          regionId: 10000002,
          locationId: 60003760,
          price: 5.0,
          volumeRemain: 500,
          volumeTotal: 1000,
          minVolume: 1,
          isBuyOrder: false,
          issued: DateTime.now(),
          duration: 30,
          range: 'station',
          isCorporation: false,
          escrow: 0.0,
          state: 'active',
        ),
      ];

      await repository.replaceAllOrders(characterId, companions);

      // Watch and verify
      final stream = repository.watchActiveOrders(characterId);
      final orders = await stream.first;

      expect(orders.length, 1);
      expect(orders.first.orderId, 1000);
      expect(orders.first.isBuyOrder, isFalse);
    });

    test('watchPrice and getPrice return correct price data', () async {
      // Insert test data
      final companions = [
        MarketPricesCompanion.insert(
          typeId: const Value(34),
          adjustedPrice: const Value(4.5),
          averagePrice: const Value(4.6),
          lastUpdated: DateTime.now(),
        ),
      ];

      await repository.replaceAllPrices(companions);

      // Verify watchPrice
      final stream = repository.watchPrice(34);
      final price = await stream.first;
      expect(price?.adjustedPrice, 4.5);

      // Verify getPrice
      final futurePrice = await repository.getPrice(34);
      expect(futurePrice?.averagePrice, 4.6);
    });
  });
}
