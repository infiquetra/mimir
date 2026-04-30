import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/network/esi_client.dart';
import '../models/character_order.dart';

/// Repository for fetching character market orders from ESI.
class OrdersRepository {
  final EsiClient _esiClient;

  OrdersRepository({required EsiClient esiClient}) : _esiClient = esiClient;

  /// Fetches the active market orders for a character from ESI.
  ///
  /// The ESI endpoint `GET /characters/{characterId}/orders/` returns only
  /// the character's currently open orders — all with an implicit
  /// `state` of "active". Historical/cancelled/expired orders are not
  /// included and require a different endpoint.
  ///
  /// Throws [EsiException] on network or auth errors.
  Future<List<CharacterOrder>> getCharacterOrders(int characterId) async {
    Log.d('ORDERS', 'getCharacterOrders($characterId) - START');
    try {
      final response = await _esiClient.authenticatedGet<List<dynamic>>(
        '/characters/$characterId/orders/',
        characterId: characterId,
      );

      final data = response.data;
      if (data == null) {
        Log.w('ORDERS', 'getCharacterOrders - ESI returned null data');
        return [];
      }

      final orders = data
          .cast<Map<String, dynamic>>()
          .map((json) => CharacterOrder.fromJson(
                json,
                characterId: characterId,
              ))
          .toList();

      Log.i('ORDERS',
          'getCharacterOrders($characterId) - fetched ${orders.length} orders');
      Log.d('ORDERS', 'getCharacterOrders($characterId) - SUCCESS');
      return orders;
    } on EsiException {
      Log.e('ORDERS', 'getCharacterOrders($characterId) - ESI error');
      rethrow;
    } catch (e, stack) {
      Log.e('ORDERS', 'getCharacterOrders($characterId) - unexpected error',
          e, stack);
      rethrow;
    }
  }
}

/// Provider for the orders repository.
final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(
    esiClient: ref.watch(esiClientProvider),
  );
});

/// Provider that fetches and caches active orders for a character.
final characterOrdersProvider =
    FutureProvider.family<List<CharacterOrder>, int>((ref, characterId) async {
  Log.d('ORDERS', 'characterOrdersProvider($characterId) - fetching');
  final repository = ref.watch(ordersRepositoryProvider);
  return repository.getCharacterOrders(characterId);
});
