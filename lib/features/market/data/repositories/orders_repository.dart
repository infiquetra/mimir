import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/core/logging/logger.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/market/data/models/character_order.dart';

/// Repository for fetching character market orders from ESI.
class OrdersRepository {
  final EsiClient _esiClient;

  OrdersRepository({required EsiClient esiClient}) : _esiClient = esiClient;

  /// Fetch active market orders for a character.
  Future<List<CharacterOrder>> getActiveOrders(int characterId) async {
    Log.d('MARKET.ORDERS', 'getActiveOrders($characterId) - START');

    final List<CharacterOrder> orders;
    try {
      final response = await _esiClient.authenticatedGet<List<dynamic>>(
        '/characters/$characterId/orders/',
        characterId: characterId,
      );

      final data = response.data;
      if (data is! List<dynamic>) {
        throw FormatException(
          'Expected List<dynamic> for orders response, got ${data.runtimeType}',
        );
      }

      orders = data.map((item) {
        if (item is! Map<String, dynamic>) {
          throw FormatException(
            'Expected Map<String, dynamic> for order item, got ${item.runtimeType}',
          );
        }
        return CharacterOrder.fromJson(item, characterId: characterId);
      }).toList();
    } catch (e, stack) {
      Log.e(
          'MARKET.ORDERS', 'getActiveOrders($characterId) - FAILED', e, stack);
      rethrow;
    }

    if (orders.isEmpty) {
      Log.i('MARKET.ORDERS', 'getActiveOrders($characterId) - no orders');
      return orders;
    }

    // Resolve type and location names via universe name lookup.
    final ids = <int>{};
    for (final order in orders) {
      ids.add(order.typeId);
      ids.add(order.locationId);
    }

    try {
      final names = await _esiClient.getUniverseNames(ids.toList());
      final nameMap = <int, String>{};
      for (final name in names) {
        nameMap[name.id] = name.name;
      }

      final resolved = orders
          .map(
            (order) => order.copyWithResolvedNames(
              typeName: nameMap[order.typeId],
              locationName: nameMap[order.locationId],
            ),
          )
          .toList();

      resolved.sort((a, b) => b.issued.compareTo(a.issued));

      Log.d('MARKET.ORDERS', 'getActiveOrders($characterId) - SUCCESS');
      return resolved;
    } catch (e, stack) {
      Log.e(
        'MARKET.ORDERS',
        'getActiveOrders($characterId) - name resolution FAILED',
        e,
        stack,
      );
      rethrow;
    }
  }
}

/// Provider for the orders repository.
final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(esiClient: ref.watch(esiClientProvider));
});

/// Provider that fetches active orders for the currently selected character.
final activeOrdersProvider = FutureProvider<List<CharacterOrder>>((ref) async {
  final activeCharacter = await ref.watch(activeCharacterProvider.future);
  if (activeCharacter == null) return const [];

  final repository = ref.watch(ordersRepositoryProvider);
  return repository.getActiveOrders(activeCharacter.characterId);
});
