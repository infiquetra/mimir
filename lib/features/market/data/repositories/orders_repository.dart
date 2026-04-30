import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/network/esi_client.dart';
import '../models/character_order.dart';

/// Repository for fetching character market orders.
class OrdersRepository {
  final EsiClient _esiClient;

  const OrdersRepository({required EsiClient esiClient})
      : _esiClient = esiClient;

  /// Fetches active market orders for the given character.
  Future<List<CharacterOrder>> getCharacterOrders(int characterId) async {
    if (characterId <= 0) {
      throw ArgumentError.value(
        characterId,
        'characterId',
        'Expected a positive EVE character ID',
      );
    }

    final endpointPath = '/characters/$characterId/orders/';

    try {
      final response = await _esiClient.authenticatedGet<dynamic>(
        endpointPath,
        characterId: characterId,
      );

      final data = response.data;
      if (data is! List<dynamic>) {
        throw FormatException(
          'Invalid ESI response: expected List for character orders, got ${data.runtimeType}',
        );
      }

      final orders = data.map((item) {
        if (item is! Map<String, dynamic>) {
          throw FormatException(
            'Invalid ESI response: expected Map order item, got ${item.runtimeType}',
          );
        }
        return CharacterOrder.fromJson(
          item,
          characterId: characterId,
        );
      }).toList();

      // Sort: buy first, then sell; within each side issued descending.
      orders.sort((a, b) {
        if (a.isBuyOrder != b.isBuyOrder) {
          return a.isBuyOrder ? -1 : 1;
        }
        return b.issued.compareTo(a.issued);
      });

      return orders;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      Log.e(
        'MARKET.ORDERS',
        'Failed to get orders — DioException',
        null,
        StackTrace.current,
      );
      Log.d(
        'MARKET.ORDERS',
        'operation=getCharacterOrders endpoint=$endpointPath '
            'characterId=$characterId statusCode=$statusCode type=DioException',
      );
      rethrow;
    } on EsiException catch (e) {
      final statusCode = e.statusCode;
      Log.e(
        'MARKET.ORDERS',
        'Failed to get orders — EsiException',
        null,
        StackTrace.current,
      );
      Log.d(
        'MARKET.ORDERS',
        'operation=getCharacterOrders endpoint=$endpointPath '
            'characterId=$characterId statusCode=$statusCode type=EsiException',
      );
      rethrow;
    } catch (e) {
      Log.e(
        'MARKET.ORDERS',
        'Failed to get orders — unexpected',
        null,
        StackTrace.current,
      );
      Log.d(
        'MARKET.ORDERS',
        'operation=getCharacterOrders endpoint=$endpointPath '
            'characterId=$characterId type=${e.runtimeType}',
      );
      rethrow;
    }
  }
}

/// Provider for the orders repository.
final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(esiClient: ref.watch(esiClientProvider));
});

/// Provider that fetches character market orders.
final characterOrdersProvider =
    FutureProvider.family<List<CharacterOrder>, int>((ref, characterId) async {
  final repository = ref.watch(ordersRepositoryProvider);
  return repository.getCharacterOrders(characterId);
});
