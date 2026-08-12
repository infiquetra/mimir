import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mimir/features/market/data/models/character_order.dart';
import 'package:mimir/features/market/data/repositories/orders_repository.dart';

// ---------------------------------------------------------------------------
// Mock EsiClient
// ---------------------------------------------------------------------------

class MockEsiClient extends Mock implements EsiClient {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _characterId = 12345;
const _issued = '2026-04-30T12:00:00Z';

Map<String, dynamic> buyOrderJson() => {
  'order_id': 100001,
  'type_id': 587,
  'region_id': 10000002,
  'location_id': 60003760,
  'price': 1200000.0,
  'volume_remain': 5,
  'volume_total': 100,
  'min_volume': 1,
  'is_buy_order': true,
  'issued': _issued,
  'duration': 90,
  'range': 'region',
  'state': 'active',
  'is_corporation': false,
  'escrow': 6000000.0,
  'type_name': 'Rifter',
  'location_name': 'Jita IV - Moon 4',
};

Map<String, dynamic> sellOrderJsonNoOptionals() => {
  'order_id': 200002,
  'type_id': 582,
  'region_id': 10000002,
  'location_id': 60003760,
  'price': 45000000.0,
  'volume_remain': 2,
  'volume_total': 5,
  'issued': _issued,
  'duration': 14,
  'range': 'station',
};

Response<dynamic> stubResponse({
  required String path,
  List<dynamic>? data,
}) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: path),
    data: data,
    statusCode: data != null ? 200 : 204,
  );
}

void main() {
  // -------------------------------------------------------------------------
  // CharacterOrder.fromJson
  // -------------------------------------------------------------------------
  group('CharacterOrder.fromJson', () {
    test('parses ESI active buy order response', () {
      final json = buyOrderJson();
      final order = CharacterOrder.fromJson(json, characterId: _characterId);

      expect(order.orderId, 100001);
      expect(order.characterId, _characterId);
      expect(order.typeId, 587);
      expect(order.typeName, 'Rifter');
      expect(order.regionId, 10000002);
      expect(order.locationId, 60003760);
      expect(order.locationName, 'Jita IV - Moon 4');
      expect(order.price, 1200000.0);
      expect(order.volumeRemain, 5);
      expect(order.volumeTotal, 100);
      expect(order.minVolume, 1);
      expect(order.isBuyOrder, true);
      expect(order.issued, DateTime.parse(_issued));
      expect(order.duration, 90);
      expect(order.range, OrderRange.region);
      expect(order.isCorporation, false);
      expect(order.escrow, 6000000.0);
      expect(order.state, OrderState.active);

      expect(order.expires, DateTime.parse('2026-07-29T12:00:00.000Z'));
      expect(order.isExpired, false);
      expect(order.fillPercent, closeTo(0.95, 1e-6));
      expect(order.totalValue, closeTo(6000000.0, 1e-6));
    });

    test('defaults optional ESI active order fields when absent', () {
      final json = sellOrderJsonNoOptionals();
      final order = CharacterOrder.fromJson(json, characterId: _characterId);

      expect(order.state, OrderState.active);
      expect(order.isBuyOrder, false);
      expect(order.minVolume, 1);
      expect(order.escrow, 0.0);
      expect(order.isCorporation, false);

      expect(order.typeName, 'Type ${order.typeId}');
      expect(order.locationName, 'Location ${order.locationId}');

      expect(order.fillPercent, closeTo(0.6, 1e-6));
      expect(order.totalValue, closeTo(90000000.0, 1e-6));
    });

    test('returns zero fill percent when volume total is zero', () {
      final json = <String, dynamic>{
        'order_id': 300003,
        'type_id': 123,
        'region_id': 10000002,
        'location_id': 60003760,
        'price': 100.0,
        'volume_remain': 0,
        'volume_total': 0,
        'issued': _issued,
        'duration': 30,
        'range': 'station',
      };
      final order = CharacterOrder.fromJson(json, characterId: _characterId);
      expect(order.fillPercent, 0.0);
    });

    test('throws FormatException for unknown order range', () {
      final json = <String, dynamic>{
        ...sellOrderJsonNoOptionals(),
        'range': 'wormhole',
      };
      expect(
        () => CharacterOrder.fromJson(json, characterId: _characterId),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Unknown order range: wormhole'),
          ),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // OrdersRepository.getCharacterOrders
  // -------------------------------------------------------------------------
  group('OrdersRepository.getCharacterOrders', () {
    late MockEsiClient mockEsiClient;
    late OrdersRepository repository;

    setUp(() {
      mockEsiClient = MockEsiClient();
      repository = OrdersRepository(esiClient: mockEsiClient);
    });

    test('fetches active orders from ESI and maps them to CharacterOrder',
        () async {
      final buyJson = buyOrderJson();
      final sellJson = sellOrderJsonNoOptionals();

      when(() => mockEsiClient.authenticatedGet(
            '/characters/$_characterId/orders/',
            characterId: _characterId,
          )).thenAnswer((_) async => stubResponse(
            path: '/characters/$_characterId/orders/',
            data: [buyJson, sellJson],
          ));

      final orders = await repository.getCharacterOrders(_characterId);

      expect(orders.length, 2);
      // buy orders sort before sell orders
      expect(orders[0].orderId, 100001);
      expect(orders[0].isBuyOrder, true);
      expect(orders[1].orderId, 200002);
      expect(orders[1].isBuyOrder, false);
      expect(orders[1].state, OrderState.active);
      expect(orders[1].minVolume, 1);

      verify(() => mockEsiClient.authenticatedGet(
            '/characters/$_characterId/orders/',
            characterId: _characterId,
          )).called(1);
    });

    test('returns empty list when ESI returns null data', () async {
      when(() => mockEsiClient.authenticatedGet(
            '/characters/$_characterId/orders/',
            characterId: _characterId,
          )).thenAnswer((_) async => stubResponse(
            path: '/characters/$_characterId/orders/',
            data: null,
          ));

      final orders = await repository.getCharacterOrders(_characterId);
      expect(orders, isEmpty);
    });

    test('throws ArgumentError when characterId is not positive', () async {
      expect(
        () => repository.getCharacterOrders(0),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Expected a positive EVE character ID'),
          ),
        ),
      );
      expect(
        () => repository.getCharacterOrders(-5),
        throwsA(isA<ArgumentError>()),
      );

      verifyNever(() => mockEsiClient.authenticatedGet(
            any(),
            characterId: any(named: 'characterId'),
          ));
    });

    test('rethrows EsiException on API error', () async {
      const cause = EsiException(
        'Forbidden - missing scope',
        statusCode: 403,
      );

      when(() => mockEsiClient.authenticatedGet(
            '/characters/$_characterId/orders/',
            characterId: _characterId,
          )).thenThrow(cause);

      expect(
        () => repository.getCharacterOrders(_characterId),
        throwsA(
          isA<EsiException>()
              .having((e) => e.message, 'message', 'Forbidden - missing scope')
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('fails when ESI response item is invalid', () async {
      final invalidJson = <String, dynamic>{
        // missing required 'order_id'
        'type_id': 587,
        'region_id': 10000002,
        'location_id': 60003760,
        'price': 100.0,
        'volume_remain': 1,
        'volume_total': 1,
        'issued': _issued,
        'duration': 30,
        'range': 'station',
      };

      when(() => mockEsiClient.authenticatedGet(
            '/characters/$_characterId/orders/',
            characterId: _characterId,
          )).thenAnswer((_) async => stubResponse(
            path: '/characters/$_characterId/orders/',
            data: [invalidJson],
          ));

      // Expect a TypeError (TypeError or _CastError) because fromJson
      // tries `json['order_id'] as int` which is null → cast fails.
      expect(
        () => repository.getCharacterOrders(_characterId),
        throwsA(isA<TypeError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // OrderSummary
  // -------------------------------------------------------------------------
  group('OrderSummary', () {
    late MockEsiClient mockEsiClient;
    late OrdersRepository repository;

    setUp(() {
      mockEsiClient = MockEsiClient();
      repository = OrdersRepository(esiClient: mockEsiClient);
    });

    test('summarizes buy and sell order counts and values', () async {
      final buyJson = buyOrderJson();
      final sellJson = sellOrderJsonNoOptionals();

      when(() => mockEsiClient.authenticatedGet(
            '/characters/$_characterId/orders/',
            characterId: _characterId,
          )).thenAnswer((_) async => stubResponse(
            path: '/characters/$_characterId/orders/',
            data: [buyJson, sellJson],
          ));

      final summary = await repository.getOrderSummary(_characterId);

      expect(summary.activeBuyOrders, 1);
      expect(summary.activeSellOrders, 1);
      expect(summary.totalBuyValue, closeTo(6000000.0, 1e-6));
      expect(summary.totalSellValue, closeTo(90000000.0, 1e-6));
      expect(summary.totalEscrow, closeTo(6000000.0, 1e-6));
    });
  });
}
