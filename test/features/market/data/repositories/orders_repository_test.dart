import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/market/data/models/character_order.dart';
import 'package:mimir/features/market/data/repositories/orders_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockEsiClient extends Mock implements EsiClient {}

class FakeResponse<T> extends Fake implements Response<T> {}

void main() {
  late MockEsiClient mockEsiClient;
  late OrdersRepository repository;

  setUpAll(() {
    registerFallbackValue(FakeResponse<List<dynamic>>());
  });

  setUp(() {
    mockEsiClient = MockEsiClient();
    repository = OrdersRepository(esiClient: mockEsiClient);
  });

  group('getCharacterOrders', () {
    const characterId = 12345678;

    test(
        'should fetch active orders from ESI and parse character orders',
        () async {
      final responseData = [
        {
          'order_id': 1,
          'type_id': 34,
          'region_id': 10000001,
          'location_id': 60003760,
          'price': 500.0,
          'volume_remain': 100,
          'volume_total': 200,
          'min_volume': 1,
          'is_buy_order': true,
          'issued': '2026-04-01T10:00:00Z',
          'duration': 30,
          'range': '5',
          // state omitted → active
          // is_corporation omitted → false
        },
        {
          'order_id': 2,
          'type_id': 35,
          'region_id': 10000002,
          'location_id': 60003882,
          'price': 1000.0,
          'volume_remain': 50,
          'volume_total': 50,
          'min_volume': 1,
          'is_buy_order': false,
          'issued': '2026-04-15T08:00:00Z',
          'duration': 90,
          'range': 'region',
          'is_corporation': true,
          'escrow': 25000.0,
        },
      ];

      // Build a mock Response<List<dynamic>>.
      final response = Response<List<dynamic>>(
        data: responseData,
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );

      when(() => mockEsiClient.authenticatedGet<List<dynamic>>(
            '/characters/$characterId/orders/',
            characterId: characterId,
          )).thenAnswer((_) async => response);

      final orders = await repository.getCharacterOrders(characterId);

      expect(orders, hasLength(2));

      // Buy order assertions
      final buyOrder = orders[0];
      expect(buyOrder.characterId, equals(characterId));
      expect(buyOrder.isBuyOrder, isTrue);
      expect(buyOrder.isCorporation, isFalse);
      expect(buyOrder.price, equals(500.0));
      expect(buyOrder.volumeRemain, equals(100));
      expect(buyOrder.volumeTotal, equals(200));
      expect(buyOrder.range, equals(OrderRange.reach_5));
      expect(buyOrder.state, equals(OrderState.active));
      expect(buyOrder.escrow, isNull);

      // Verify computed getters
      expect(buyOrder.fillPercent, equals(0.5));
      expect(buyOrder.remainingValue, equals(500.0 * 100));
      expect(buyOrder.totalValue, equals(500.0 * 200));
      expect(buyOrder.isExpired, isFalse);

      // Sell order assertions
      final sellOrder = orders[1];
      expect(sellOrder.isBuyOrder, isFalse);
      expect(sellOrder.isCorporation, isTrue);
      expect(sellOrder.escrow, equals(25000.0));
      expect(sellOrder.range, equals(OrderRange.region));
      expect(sellOrder.state, equals(OrderState.active));
      expect(sellOrder.fillPercent, equals(0.0)); // fully remaining, nothing filled yet
    });

    test('should return empty list for empty ESI response', () async {
      final response = Response<List<dynamic>>(
        data: <dynamic>[],
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );

      when(() => mockEsiClient.authenticatedGet<List<dynamic>>(
            '/characters/$characterId/orders/',
            characterId: characterId,
          )).thenAnswer((_) async => response);

      final orders = await repository.getCharacterOrders(characterId);

      expect(orders, isEmpty);
    });

    test('should rethrow EsiException on scope error', () async {
      when(() => mockEsiClient.authenticatedGet<List<dynamic>>(
            '/characters/$characterId/orders/',
            characterId: characterId,
          )).thenThrow(
        const EsiException('Forbidden - missing scope', statusCode: 403),
      );

      expect(
        () => repository.getCharacterOrders(characterId),
        throwsA(isA<EsiException>().having(
          (e) => e.isScopeError,
          'isScopeError',
          isTrue,
        )),
      );
    });
  });

  group('CharacterOrder.fromJson', () {
    test('should reject volume_total of zero (avoids division by zero)',
        () {
      final json = {
        'order_id': 1,
        'type_id': 34,
        'region_id': 10000001,
        'location_id': 60003760,
        'price': 100.0,
        'volume_remain': 0,
        'volume_total': 0, // zero — should not crash
        'min_volume': 1,
        'is_buy_order': true,
        'issued': '2026-04-01T10:00:00Z',
        'duration': 30,
        'range': 'station',
      };

      final order = CharacterOrder.fromJson(json, characterId: 123);

      // fillPercent must not throw — returns 0.0 for zero volumeTotal
      expect(order.fillPercent, equals(0.0));
      expect(order.volumeTotal, equals(0));
    });

    test('should throw FormatException for unknown range value', () {
      final json = {
        'order_id': 1,
        'type_id': 34,
        'region_id': 10000001,
        'location_id': 60003760,
        'price': 100.0,
        'volume_remain': 10,
        'volume_total': 100,
        'min_volume': 1,
        'is_buy_order': true,
        'issued': '2026-04-01T10:00:00Z',
        'duration': 30,
        'range': 'unknown_range',
      };

      expect(
        () => CharacterOrder.fromJson(json, characterId: 123),
        throwsA(isA<FormatException>()),
      );
    });

    test('should default state to active when omitted', () {
      final json = {
        'order_id': 1,
        'type_id': 34,
        'region_id': 10000001,
        'location_id': 60003760,
        'price': 100.0,
        'volume_remain': 10,
        'volume_total': 100,
        'min_volume': 1,
        'is_buy_order': false,
        'issued': '2026-04-01T10:00:00Z',
        'duration': 30,
        'range': 'solarsystem',
        // state omitted
      };

      final order = CharacterOrder.fromJson(json, characterId: 123);
      expect(order.state, equals(OrderState.active));
    });
  });
}
