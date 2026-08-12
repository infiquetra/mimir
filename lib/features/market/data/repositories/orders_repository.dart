import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/character_order.dart';

// ---------------------------------------------------------------------------
// Minimal self-contained abstractions (the full mimir core/ infrastructure
// does not exist in this fresh Flutter template; these are the contracts the
// plan's imports would resolve to in the real codebase).
// ---------------------------------------------------------------------------

/// A runtime exception thrown by [EsiClient] on API errors.
class EsiException implements Exception {
  final String message;
  final int? statusCode;

  const EsiException(this.message, {this.statusCode});

  @override
  String toString() => 'EsiException: $message (status: $statusCode)';
}

/// Abstract ESI API client that the repository depends on.
///
/// In the full mimir codebase this lives in `lib/core/network/esi_client.dart`;
/// for this PR we define the minimal contract so the repository and its tests
/// are self-contained.
abstract class EsiClient {
  /// Performs an authenticated GET request against the ESI API.
  ///
  /// [path] is the ESI path (e.g. `/characters/123/orders/`).
  /// [characterId] is the EVE character whose token should be used.
  ///
  /// Returns a Dio [Response] whose `data` is a [List<dynamic>] of JSON maps.
  Future<Response<dynamic>> authenticatedGet(
    String path, {
    required int characterId,
  });
}

/// Minimal logger used by [OrdersRepository] to record error context.
///
/// In the full codebase this is `Log` from `lib/core/logging/logger.dart`.
class _Log {
  static void e(String tag, String message, Object error, StackTrace stack) {
    stderr.writeln('[ERROR] $tag: $message ($error)');
  }
}

// ---------------------------------------------------------------------------
// OrderSummary – aggregate view
// ---------------------------------------------------------------------------

/// Aggregated counts and values for a set of active orders.
class OrderSummary {
  final int activeBuyOrders;
  final int activeSellOrders;
  final double totalBuyValue;
  final double totalSellValue;
  final double totalEscrow;

  const OrderSummary({
    required this.activeBuyOrders,
    required this.activeSellOrders,
    required this.totalBuyValue,
    required this.totalSellValue,
    required this.totalEscrow,
  });
}

// ---------------------------------------------------------------------------
// OrdersRepository
// ---------------------------------------------------------------------------

/// Repository that fetches character market orders from ESI.
class OrdersRepository {
  final EsiClient _esiClient;

  const OrdersRepository({required EsiClient esiClient})
      : _esiClient = esiClient;

  /// Fetches active orders for [characterId] from ESI and returns them
  /// as [CharacterOrder] instances, sorted for stable display.
  ///
  /// Throws [ArgumentError] if [characterId] is not positive (caller error,
  /// no ESI call made).
  ///
  /// Throws [EsiException] if the ESI call itself fails.
  ///
  /// Throws a cast / parse error if the ESI response contains invalid data.
  Future<List<CharacterOrder>> getCharacterOrders(int characterId) async {
    if (characterId <= 0) {
      throw ArgumentError.value(
        characterId,
        'characterId',
        'Expected a positive EVE character ID',
      );
    }

    try {
      final response = await _esiClient.authenticatedGet(
        '/characters/$characterId/orders/',
        characterId: characterId,
      );

      final data = response.data as List<dynamic>?;
      if (data == null) return [];

      final orders = data.map((dynamic item) {
        return CharacterOrder.fromJson(
          item as Map<String, dynamic>,
          characterId: characterId,
        );
      }).toList();

      // Stable sort: active first, buy before sell, issued descending
      orders.sort((a, b) {
        final activeCmp =
            _stateOrder(a.state).compareTo(_stateOrder(b.state));
        if (activeCmp != 0) return activeCmp;

        final buyCmp = (b.isBuyOrder ? 1 : 0).compareTo(a.isBuyOrder ? 1 : 0);
        if (buyCmp != 0) return buyCmp;

        return b.issued.compareTo(a.issued);
      });

      return orders;
    } on EsiException {
      rethrow;
    } on DioException catch (e) {
      final wrapped = EsiException(
        'ESI call failed: ${e.message}',
        statusCode: e.response?.statusCode,
      );
      _Log.e('MARKET.ORDERS', 'getCharacterOrders($characterId) - FAILED',
          wrapped, StackTrace.current);
      throw wrapped;
    }
  }

  /// Computes an [OrderSummary] for [characterId] by fetching active orders
  /// and aggregating buy / sell counts and values.
  Future<OrderSummary> getOrderSummary(int characterId) async {
    final orders = await getCharacterOrders(characterId);

    final buyOrders = orders.where((o) => o.isBuyOrder).toList();
    final sellOrders = orders.where((o) => !o.isBuyOrder).toList();

    final totalBuyValue =
        buyOrders.fold<double>(0.0, (sum, o) => sum + o.totalValue);
    final totalSellValue =
        sellOrders.fold<double>(0.0, (sum, o) => sum + o.totalValue);
    final totalEscrow =
        buyOrders.fold<double>(0.0, (sum, o) => sum + o.escrow);

    return OrderSummary(
      activeBuyOrders: buyOrders.length,
      activeSellOrders: sellOrders.length,
      totalBuyValue: totalBuyValue,
      totalSellValue: totalSellValue,
      totalEscrow: totalEscrow,
    );
  }

  static int _stateOrder(OrderState state) {
    switch (state) {
      case OrderState.active:
        return 0;
      case OrderState.fulfilled:
        return 1;
      case OrderState.cancelled:
        return 2;
      case OrderState.expired:
        return 3;
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Provider that constructs [OrdersRepository] wired to [EsiClient].
///
/// In the full mimir codebase this is:
/// ```dart
/// final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
///   return OrdersRepository(esiClient: ref.watch(esiClientProvider));
/// });
/// ```
/// For this PR the provider returns a repository backed by a `_NoOpEsiClient`
/// that throws if called — real wiring requires `lib/core/di/providers.dart`
/// (out of scope). The [ActiveOrdersScreen] overrides this provider with a
/// concrete implementation supplied by the caller.

class _NoOpEsiClient implements EsiClient {
  @override
  Future<Response<dynamic>> authenticatedGet(
    String path, {
    required int characterId,
  }) {
    throw UnimplementedError(
      'EsiClient not wired — override ordersRepositoryProvider with a real implementation',
    );
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(esiClient: _NoOpEsiClient());
});
