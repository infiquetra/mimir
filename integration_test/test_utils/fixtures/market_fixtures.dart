import 'package:mimir/core/network/esi_client.dart';

/// Test fixtures for Market data (Orders and Prices).
class MarketFixtures {
  static final _baseDate = DateTime(2024, 1, 1, 12, 0);

  /// Test market prices data
  static List<MarketPriceData> testMarketPrices() {
    return [
      MarketPriceData(
        typeId: 34, // Tritanium
        adjustedPrice: 4.5,
        averagePrice: 4.6,
      ),
      MarketPriceData(
        typeId: 35, // Pyerite
        adjustedPrice: 12.0,
        averagePrice: 12.5,
      ),
    ];
  }

  /// Test character active orders data
  static List<CharacterOrderData> testCharacterOrders() {
    return [
      CharacterOrderData(
        orderId: 30001,
        typeId: 34, // Tritanium
        regionId: 10000002, // The Forge
        locationId: 60003760, // Jita IV - Moon 4 - Caldari Navy Assembly Plant
        price: 5.0,
        volumeRemain: 500000,
        volumeTotal: 1000000,
        minVolume: 1,
        isBuyOrder: false, // Sell Order
        issued: _baseDate.subtract(const Duration(days: 2)),
        duration: 30,
        range: 'station',
        isCorporation: false,
        escrow: 0.0,
        state: 'active',
      ),
      CharacterOrderData(
        orderId: 30002,
        typeId: 35, // Pyerite
        regionId: 10000002, // The Forge
        locationId: 60003760, // Jita IV - Moon 4
        price: 11.5,
        volumeRemain: 100000,
        volumeTotal: 100000,
        minVolume: 100,
        isBuyOrder: true, // Buy Order
        issued: _baseDate.subtract(const Duration(days: 1)),
        duration: 90,
        range: 'region',
        isCorporation: false,
        escrow: 1150000.0,
        state: 'active',
      ),
    ];
  }
}
