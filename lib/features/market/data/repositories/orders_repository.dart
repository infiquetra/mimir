import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/core/logging/logger.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/market/data/models/character_order.dart';

/// Repository for fetching and managing character market orders.
///
/// Coordinates with ESI to retrieve active orders and resolves
/// type/location names via [EsiClient.getUniverseNames].
class OrdersRepository {
  final EsiClient _esiClient;

  OrdersRepository({required EsiClient esiClient}) : _esiClient = esiClient;

  /// Fetches active market orders for [characterId] from ESI.
  ///
  /// Calls `GET /characters/{characterId}/orders/` and resolves
  /// type names and location names via a single call to
  /// [EsiClient.getUniverseNames]. Results are sorted: buy orders
  /// first, then sell orders, each group ordered by [CharacterOrder.issued]
  /// descending.
  ///
  /// Returns an empty list if the character has no active orders.
  ///
  /// Throws [ArgumentError] if [characterId] is not positive.
  /// Throws on any ESI or name-resolution failure.
  Future<List<CharacterOrder>> getCharacterOrders(int characterId) async {
    if (characterId <= 0) {
      throw ArgumentError.value(
        characterId,
        'characterId',
        'must be a positive EVE character id',
      );
    }

    Log.d('MARKET', 'getCharacterOrders($characterId) - START');

    try {
      // 1. Fetch active orders from ESI.
      Log.d('MARKET', 'getCharacterOrders - fetching from ESI');
      final response = await _esiClient.authenticatedGet<List<dynamic>>(
        '/characters/$characterId/orders/',
        characterId: characterId,
      );

      final rawList = response.data;
      if (rawList == null || rawList.isEmpty) {
        Log.i('MARKET', 'getCharacterOrders - no active orders');
        return [];
      }

      Log.i('MARKET',
          'getCharacterOrders - fetched ${rawList.length} raw orders');

      // 2. Extract raw maps and collect unique type/location IDs.
      final rawOrders = <Map<String, dynamic>>[];
      final typeIds = <int>{};
      final locationIds = <int>{};

      for (final item in rawList) {
        if (item is! Map<String, dynamic>) continue;
        rawOrders.add(item);

        final typeId = item['type_id'];
        if (typeId is int) typeIds.add(typeId);

        final locationId = item['location_id'];
        if (locationId is int) locationIds.add(locationId);
      }

      if (rawOrders.isEmpty) {
        Log.i('MARKET',
            'getCharacterOrders - raw list contained no valid maps');
        return [];
      }

      // 3. Resolve type and location names in a single call.
      final allIds = {...typeIds, ...locationIds}.toList();
      Log.d('MARKET',
          'getCharacterOrders - resolving ${allIds.length} universe names');
      final namesResult = await _esiClient.getUniverseNames(allIds);

      // Build lookup maps (id → name).
      final nameMap = <int, String>{};
      for (final name in namesResult) {
        nameMap[name.id] = name.name;
      }

      // 4. Map raw orders to CharacterOrder instances.
      final orders = rawOrders.map((raw) {
        final typeId = raw['type_id'] as int;
        final locationId = raw['location_id'] as int;

        return CharacterOrder.fromEsiJson(
          raw,
          characterId: characterId,
          typeName: nameMap[typeId] ?? 'Unknown type $typeId',
          locationName: nameMap[locationId] ?? 'Unknown location $locationId',
        );
      }).toList();

      // 5. Sort: buy orders first, sell orders second,
      //    each group by issued descending.
      orders.sort((a, b) {
        if (a.isBuyOrder && !b.isBuyOrder) return -1;
        if (!a.isBuyOrder && b.isBuyOrder) return 1;
        return b.issued.compareTo(a.issued);
      });

      Log.i('MARKET',
          'getCharacterOrders - returning ${orders.length} orders');
      Log.d('MARKET', 'getCharacterOrders($characterId) - SUCCESS');
      return orders;
    } catch (e, stack) {
      Log.e('MARKET', 'getCharacterOrders($characterId) - FAILED', e, stack);
      rethrow;
    }
  }
}

/// Summary statistics for a set of character orders.
///
/// Derived purely from an already-loaded list of [CharacterOrder]s —
/// performs no ESI I/O.
class OrderSummary {
  /// Active buy orders.
  final List<CharacterOrder> activeBuyOrders;

  /// Active sell orders.
  final List<CharacterOrder> activeSellOrders;

  /// Total ISK value of buy orders (∑ price × volumeRemain).
  final double totalBuyValue;

  /// Total ISK value of sell orders (∑ price × volumeRemain).
  final double totalSellValue;

  /// Total escrow locked in buy orders.
  final double totalEscrow;

  const OrderSummary({
    required this.activeBuyOrders,
    required this.activeSellOrders,
    required this.totalBuyValue,
    required this.totalSellValue,
    required this.totalEscrow,
  });

  /// Number of active buy orders.
  int get buyCount => activeBuyOrders.length;

  /// Number of active sell orders.
  int get sellCount => activeSellOrders.length;

  /// Total number of active orders.
  int get totalOrders => buyCount + sellCount;

  /// Computes an [OrderSummary] from a list of [CharacterOrder]s.
  ///
  /// Pure computation — does not call ESI or any repository method.
  factory OrderSummary.fromOrders(List<CharacterOrder> orders) {
    final buyOrders =
        orders.where((o) => o.isBuyOrder).toList(growable: false);
    final sellOrders =
        orders.where((o) => !o.isBuyOrder).toList(growable: false);

    final totalBuyValue =
        buyOrders.fold<double>(0, (sum, o) => sum + o.remainingValue);
    final totalSellValue =
        sellOrders.fold<double>(0, (sum, o) => sum + o.remainingValue);
    final totalEscrow =
        buyOrders.fold<double>(0, (sum, o) => sum + o.escrow);

    return OrderSummary(
      activeBuyOrders: buyOrders,
      activeSellOrders: sellOrders,
      totalBuyValue: totalBuyValue,
      totalSellValue: totalSellValue,
      totalEscrow: totalEscrow,
    );
  }
}

/// Provider for the orders repository.
final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(
    esiClient: ref.watch(esiClientProvider),
  );
});

/// Provider that fetches active character orders by character ID.
///
/// Performs exactly one authenticated ESI fetch per evaluation.
/// Summary UI should derive [OrderSummary.fromOrders] from the returned
/// list rather than watching a separate summary provider.
final characterOrdersProvider =
    FutureProvider.family<List<CharacterOrder>, int>((ref, characterId) async {
  final repository = ref.watch(ordersRepositoryProvider);
  return repository.getCharacterOrders(characterId);
});
