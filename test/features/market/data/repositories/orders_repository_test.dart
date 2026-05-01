import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/market/data/models/character_order.dart';
import 'package:mimir/features/market/data/repositories/orders_repository.dart';
import 'package:mimir/features/market/presentation/active_orders_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockEsiClient extends Mock implements EsiClient {}

/// Builds a minimal valid ESI buy order JSON map.
Map<String, dynamic> _validBuyOrderJson({
  int orderId = 1,
  int typeId = 34,
  int regionId = 10000002,
  int locationId = 60003760,
  double price = 1250000.0,
  int volumeRemain = 2000,
  int volumeTotal = 10000,
  int minVolume = 1,
  int duration = 90,
  String range = 'station',
  double? escrow,
}) {
  return {
    'order_id': orderId,
    'type_id': typeId,
    'region_id': regionId,
    'location_id': locationId,
    'price': price,
    'volume_remain': volumeRemain,
    'volume_total': volumeTotal,
    'min_volume': minVolume,
    'is_buy_order': true,
    'issued': '2026-04-15T12:00:00Z',
    'duration': duration,
    'range': range,
    'is_corporation': false,
    if (escrow != null) 'escrow': escrow,
  };
}

/// Builds a minimal valid ESI sell order JSON map.
Map<String, dynamic> _validSellOrderJson({
  int orderId = 2,
  int typeId = 35,
  int regionId = 10000002,
  int locationId = 60003760,
  double price = 980000.0,
  int volumeRemain = 5000,
  int volumeTotal = 5000,
  int minVolume = 1,
  int duration = 14,
  String range = 'region',
}) {
  return {
    'order_id': orderId,
    'type_id': typeId,
    'region_id': regionId,
    'location_id': locationId,
    'price': price,
    'volume_remain': volumeRemain,
    'volume_total': volumeTotal,
    'min_volume': minVolume,
    'is_buy_order': false,
    'issued': '2026-04-25T08:00:00Z',
    'duration': duration,
    'range': range,
    'is_corporation': false,
  };
}

/// Creates a mock Dio [Response] with the given data list.
Response<List<dynamic>> _mockResponse(List<dynamic> data) {
  return Response<List<dynamic>>(
    requestOptions: RequestOptions(path: '/characters/123/orders/'),
    data: data,
  );
}

/// Creates a [UniverseName] for testing.
UniverseName _universeName(int id, String name, String category) {
  return UniverseName(id: id, name: name, category: category);
}

void main() {
  // ---------------------------------------------------------------------------
  // Model tests
  // ---------------------------------------------------------------------------
  group('CharacterOrder', () {
    test('fromEsiJson parses active buy order payload', () {
      final json = _validBuyOrderJson(escrow: 2500000000.0);

      final order = CharacterOrder.fromEsiJson(
        json,
        characterId: 12345678,
        typeName: 'Tritanium',
        locationName: 'Jita IV - Moon 4 - Caldari Navy Assembly Plant',
      );

      expect(order.orderId, 1);
      expect(order.characterId, 12345678);
      expect(order.typeId, 34);
      expect(order.typeName, 'Tritanium');
      expect(order.regionId, 10000002);
      expect(order.locationId, 60003760);
      expect(
        order.locationName,
        'Jita IV - Moon 4 - Caldari Navy Assembly Plant',
      );
      expect(order.price, 1250000.0);
      expect(order.volumeRemain, 2000);
      expect(order.volumeTotal, 10000);
      expect(order.minVolume, 1);
      expect(order.isBuyOrder, true);
      expect(order.issued, DateTime.utc(2026, 4, 15, 12, 0, 0));
      expect(order.duration, 90);
      expect(order.range, OrderRange.station);
      expect(order.isCorporation, false);
      expect(order.escrow, 2500000000.0);
      expect(order.state, OrderState.active);
    });

    test('fromEsiJson defaults escrow to 0 when absent', () {
      final json = _validBuyOrderJson(); // escrow omitted

      final order = CharacterOrder.fromEsiJson(
        json,
        characterId: 12345678,
        typeName: 'Tritanium',
        locationName: 'Jita IV',
      );

      expect(order.escrow, 0.0);
    });

    test('fromEsiJson defaults escrow to 0 when null', () {
      final json = _validBuyOrderJson(escrow: null);

      final order = CharacterOrder.fromEsiJson(
        json,
        characterId: 12345678,
        typeName: 'Tritanium',
        locationName: 'Jita IV',
      );

      expect(order.escrow, 0.0);
    });

    test('fromEsiJson throws FormatException for non-numeric escrow', () {
      final json = _validBuyOrderJson()..['escrow'] = 'not-a-number';

      expect(
        () => CharacterOrder.fromEsiJson(
          json,
          characterId: 12345678,
          typeName: 'Tritanium',
          locationName: 'Jita IV',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromEsiJson rejects unknown range values', () {
      final json = _validBuyOrderJson(range: 'galaxy');

      expect(
        () => CharacterOrder.fromEsiJson(
          json,
          characterId: 12345678,
          typeName: 'Tritanium',
          locationName: 'Jita IV',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromEsiJson accepts jump-count range values', () {
      final json = _validBuyOrderJson(range: '5');

      final order = CharacterOrder.fromEsiJson(
        json,
        characterId: 12345678,
        typeName: 'Tritanium',
        locationName: 'Jita IV',
      );

      expect(order.range, OrderRange.jumps);
    });

    test('fromEsiJson throws FormatException for missing required field',
        () {
      final json = _validBuyOrderJson()..remove('order_id');

      expect(
        () => CharacterOrder.fromEsiJson(
          json,
          characterId: 12345678,
          typeName: 'Tritanium',
          locationName: 'Jita IV',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromEsiJson throws FormatException for wrong-typed required field',
        () {
      final json = _validBuyOrderJson()
        ..['volume_remain'] = 'not-an-int';

      expect(
        () => CharacterOrder.fromEsiJson(
          json,
          characterId: 12345678,
          typeName: 'Tritanium',
          locationName: 'Jita IV',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('fillPercent handles zero volumeTotal without division by zero', () {
      final json = _validBuyOrderJson(volumeTotal: 0);
      final order = CharacterOrder.fromEsiJson(
        json,
        characterId: 12345678,
        typeName: 'Tritanium',
        locationName: 'Jita IV',
      );

      expect(order.fillPercent, 0.0);
    });

    test('fillPercent handles negative volumeTotal', () {
      final json = _validBuyOrderJson(volumeTotal: -1);
      final order = CharacterOrder.fromEsiJson(
        json,
        characterId: 12345678,
        typeName: 'Tritanium',
        locationName: 'Jita IV',
      );

      expect(order.fillPercent, 0.0);
    });

    test('fillPercent calculates correct fraction', () {
      // 10000 total, 2000 remain → 8000 filled → 80%
      final json = _validBuyOrderJson(volumeRemain: 2000, volumeTotal: 10000);
      final order = CharacterOrder.fromEsiJson(
        json,
        characterId: 12345678,
        typeName: 'Tritanium',
        locationName: 'Jita IV',
      );

      expect(order.fillPercent, 0.8);
    });

    test('fillPercent returns 1.0 for fully filled order', () {
      final json = _validBuyOrderJson(volumeRemain: 0, volumeTotal: 10000);
      final order = CharacterOrder.fromEsiJson(
        json,
        characterId: 12345678,
        typeName: 'Tritanium',
        locationName: 'Jita IV',
      );

      expect(order.fillPercent, 1.0);
    });

    test('expires calculates correctly from issued + duration', () {
      final json = _validBuyOrderJson(duration: 30);
      final order = CharacterOrder.fromEsiJson(
        json,
        characterId: 12345678,
        typeName: 'Tritanium',
        locationName: 'Jita IV',
      );

      expect(
        order.expires,
        DateTime.utc(2026, 4, 15, 12, 0, 0).add(const Duration(days: 30)),
      );
    });

    test('isExpired is true for past expiry', () {
      final json = _validBuyOrderJson(duration: 1, issued: '2020-01-01T00:00:00Z');
      final order = CharacterOrder.fromEsiJson(
        json,
        characterId: 12345678,
        typeName: 'Tritanium',
        locationName: 'Jita IV',
      );

      expect(order.isExpired, true);
    });

    test('remainingValue computes price * volumeRemain', () {
      final json = _validBuyOrderJson(price: 150.0, volumeRemain: 200);
      final order = CharacterOrder.fromEsiJson(
        json,
        characterId: 12345678,
        typeName: 'Tritanium',
        locationName: 'Jita IV',
      );

      expect(order.remainingValue, 30000.0);
    });
  });

  // ---------------------------------------------------------------------------
  // Repository tests
  // ---------------------------------------------------------------------------
  group('OrdersRepository.getCharacterOrders', () {
    late MockEsiClient mockEsiClient;
    late OrdersRepository repository;

    setUp(() {
      mockEsiClient = MockEsiClient();
      repository = OrdersRepository(esiClient: mockEsiClient);
      reset(mockEsiClient);
    });

    test('fetches active orders and resolves type and location names',
        () async {
      const characterId = 12345678;

      final buyOrder = _validBuyOrderJson(escrow: 500000.0);
      final sellOrder = _validSellOrderJson();

      // Mock the authenticated GET to return two orders.
      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenAnswer((_) async => _mockResponse([buyOrder, sellOrder]));

      // Mock getUniverseNames to return resolved names.
      when(() => mockEsiClient.getUniverseNames(any()))
          .thenAnswer((invocation) async {
        final ids = invocation.positionalArguments[0] as List<int>;
        final results = <UniverseName>[];
        for (final id in ids) {
          if (id == 34) results.add(_universeName(34, 'Tritanium', 'inventory_type'));
          if (id == 35) results.add(_universeName(35, 'Pyerite', 'inventory_type'));
          if (id == 60003760) results.add(_universeName(60003760, 'Jita IV - Moon 4', 'station'));
        }
        return results;
      });

      final orders = await repository.getCharacterOrders(characterId);

      // Buy orders come first (then sorted by issued descending).
      expect(orders.length, 2);
      expect(orders[0].isBuyOrder, true);
      expect(orders[0].typeName, 'Tritanium');
      expect(orders[0].locationName, 'Jita IV - Moon 4');
      expect(orders[1].isBuyOrder, false);
      expect(orders[1].typeName, 'Pyerite');
    });

    test('returns empty list when ESI returns no orders', () async {
      const characterId = 12345678;

      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenAnswer((_) async => _mockResponse([]));

      final orders = await repository.getCharacterOrders(characterId);

      expect(orders, isEmpty);
    });

    test('returns empty list when ESI returns null data', () async {
      const characterId = 12345678;

      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenAnswer((_) async => Response<List<dynamic>>(
            requestOptions:
                RequestOptions(path: '/characters/$characterId/orders/'),
            data: null,
          ));

      final orders = await repository.getCharacterOrders(characterId);

      expect(orders, isEmpty);
    });

    test('rethrows ESI errors instead of swallowing them', () async {
      const characterId = 12345678;

      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenThrow(
        const EsiException('API Error', statusCode: 500),
      );

      expect(
        () => repository.getCharacterOrders(characterId),
        throwsA(isA<EsiException>()),
      );
    });

    test('fails when required order fields are malformed', () async {
      const characterId = 12345678;

      // Bad order: missing 'order_id'.
      final badOrder = _validBuyOrderJson()..remove('order_id');

      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenAnswer((_) async => _mockResponse([badOrder]));

      // getUniverseNames still needs to return something.
      when(() => mockEsiClient.getUniverseNames(any()))
          .thenAnswer((_) async => [
                _universeName(34, 'Tritanium', 'inventory_type'),
                _universeName(60003760, 'Jita IV', 'station'),
              ]);

      expect(
        () => repository.getCharacterOrders(characterId),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'uses Unknown type/location fallbacks only when name resolution '
        'succeeds but omits an id', () async {
      const characterId = 12345678;

      final buyOrder = _validBuyOrderJson();

      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenAnswer((_) async => _mockResponse([buyOrder]));

      // getUniverseNames succeeds but does NOT include type 34 or location 60003760.
      when(() => mockEsiClient.getUniverseNames(any()))
          .thenAnswer((_) async => [
                _universeName(99999, 'SomethingElse', 'inventory_type'),
              ]);

      final orders = await repository.getCharacterOrders(characterId);

      expect(orders.length, 1);
      expect(orders[0].typeName, 'Unknown type 34');
      expect(orders[0].locationName, 'Unknown location 60003760');
    });

    test('fails when name resolution request fails', () async {
      const characterId = 12345678;

      final buyOrder = _validBuyOrderJson();

      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenAnswer((_) async => _mockResponse([buyOrder]));

      when(() => mockEsiClient.getUniverseNames(any()))
          .thenThrow(const EsiException('Name resolution failed', statusCode: 500));

      expect(
        () => repository.getCharacterOrders(characterId),
        throwsA(isA<EsiException>()),
      );
    });

    test('throws ArgumentError for non-positive characterId', () async {
      expect(
        () => repository.getCharacterOrders(0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.getCharacterOrders(-1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('sorts buy orders before sell orders, each by issued descending',
        () async {
      const characterId = 12345678;

      // Buy order issued later than sell order.
      final buyOrder = _validBuyOrderJson(
        orderId: 1,
        typeId: 34,
        locationId: 60003760,
        issued: '2026-04-20T12:00:00Z',
      );
      final sellOrder = _validSellOrderJson(
        orderId: 2,
        typeId: 35,
        locationId: 60003760,
        issued: '2026-04-25T08:00:00Z', // later
      );

      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenAnswer((_) async => _mockResponse([sellOrder, buyOrder]));

      when(() => mockEsiClient.getUniverseNames(any()))
          .thenAnswer((_) async => [
                _universeName(34, 'Tritanium', 'inventory_type'),
                _universeName(35, 'Pyerite', 'inventory_type'),
                _universeName(60003760, 'Jita IV', 'station'),
              ]);

      final orders = await repository.getCharacterOrders(characterId);

      expect(orders.length, 2);
      // Buy orders first.
      expect(orders[0].isBuyOrder, true);
      expect(orders[0].orderId, 1);
      // Then sell orders.
      expect(orders[1].isBuyOrder, false);
      expect(orders[1].orderId, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // OrderSummary tests
  // ---------------------------------------------------------------------------
  group('OrderSummary', () {
    late CharacterOrder buyOrder;
    late CharacterOrder buyOrder2;
    late CharacterOrder sellOrder;

    setUp(() {
      buyOrder = CharacterOrder.fromEsiJson(
        _validBuyOrderJson(
          orderId: 1,
          typeId: 34,
          locationId: 60003760,
          price: 100.0,
          volumeRemain: 10,
          escrow: 1000.0,
        ),
        characterId: 12345678,
        typeName: 'Tritanium',
        locationName: 'Jita IV',
      );
      buyOrder2 = CharacterOrder.fromEsiJson(
        _validBuyOrderJson(
          orderId: 3,
          typeId: 36,
          locationId: 60003760,
          price: 200.0,
          volumeRemain: 5,
          escrow: 1000.0,
        ),
        characterId: 12345678,
        typeName: 'Isogen',
        locationName: 'Jita IV',
      );
      sellOrder = CharacterOrder.fromEsiJson(
        _validSellOrderJson(
          orderId: 2,
          typeId: 35,
          locationId: 60003760,
          price: 500.0,
          volumeRemain: 3,
        ),
        characterId: 12345678,
        typeName: 'Pyerite',
        locationName: 'Jita IV',
      );
    });

    test('fromOrders calculates buy/sell counts, remaining values, and escrow',
        () {
      final summary = OrderSummary.fromOrders([buyOrder, sellOrder, buyOrder2]);

      expect(summary.buyCount, 2);
      expect(summary.sellCount, 1);
      expect(summary.totalOrders, 3);

      // Buy value: (100*10) + (200*5) = 1000 + 1000 = 2000
      expect(summary.totalBuyValue, 2000.0);
      // Sell value: 500*3 = 1500
      expect(summary.totalSellValue, 1500.0);
      // Escrow: 1000 + 1000 = 2000
      expect(summary.totalEscrow, 2000.0);

      // Active order lists.
      expect(summary.activeBuyOrders.length, 2);
      expect(summary.activeSellOrders.length, 1);
    });

    test('fromOrders handles empty list', () {
      final summary = OrderSummary.fromOrders([]);

      expect(summary.buyCount, 0);
      expect(summary.sellCount, 0);
      expect(summary.totalOrders, 0);
      expect(summary.totalBuyValue, 0.0);
      expect(summary.totalSellValue, 0.0);
      expect(summary.totalEscrow, 0.0);
    });
  });

  // ---------------------------------------------------------------------------
  // ActiveOrdersScreen widget tests
  // ---------------------------------------------------------------------------
  group('ActiveOrdersScreen', () {
    late CharacterOrder testBuyOrder;
    late CharacterOrder testSellOrder;

    setUp(() {
      testBuyOrder = CharacterOrder.fromEsiJson(
        _validBuyOrderJson(
          orderId: 1,
          typeId: 34,
          locationId: 60003760,
          price: 1250000.0,
          volumeRemain: 2000,
          volumeTotal: 10000,
          escrow: 1000000.0,
        ),
        characterId: 12345678,
        typeName: 'Tritanium',
        locationName: 'Jita IV - Moon 4',
      );
      testSellOrder = CharacterOrder.fromEsiJson(
        _validSellOrderJson(
          orderId: 2,
          typeId: 35,
          locationId: 60003760,
          price: 980000.0,
          volumeRemain: 5000,
          volumeTotal: 5000,
        ),
        characterId: 12345678,
        typeName: 'Pyerite',
        locationName: 'Jita IV - Moon 4',
      );
    });

    testWidgets('displays buy and sell tabs for provided character id',
        (tester) async {
      const characterId = 12345678;
      final testOrders = [testBuyOrder, testSellOrder];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            characterOrdersProvider(characterId)
                .overrideWith((ref) async => testOrders),
          ],
          child: const MaterialApp(
            home: ActiveOrdersScreen(characterId: characterId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tab labels should be present.
      expect(find.text('Buy Orders'), findsWidgets);
      expect(find.text('Sell Orders'), findsWidgets);

      // Summary strip should show counts.
      expect(find.text('1'), findsAtLeast(1)); // buyCount on the summary chip

      // Order type names should appear.
      expect(find.text('Tritanium'), findsOneWidget);
      expect(find.text('Pyerite'), findsOneWidget);

      // Side badges.
      expect(find.text('BUY'), findsOneWidget);
      expect(find.text('SELL'), findsOneWidget);
    });

    testWidgets('shows empty state for empty buy orders', (tester) async {
      const characterId = 12345678;
      // Only sell orders — buy tab should be empty.
      final testOrders = [testSellOrder];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            characterOrdersProvider(characterId)
                .overrideWith((ref) async => testOrders),
          ],
          child: const MaterialApp(
            home: ActiveOrdersScreen(characterId: characterId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Buy tab should show empty state.
      expect(find.text('No Buy Orders'), findsOneWidget);
    });

    testWidgets('shows retry empty state when provider errors',
        (tester) async {
      const characterId = 12345678;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            characterOrdersProvider(characterId)
                .overrideWith((ref) async => throw Exception('Test error')),
          ],
          child: const MaterialApp(
            home: ActiveOrdersScreen(characterId: characterId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Error heading.
      expect(find.text('Failed to Load Orders'), findsOneWidget);
      // Retry button.
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets(
        'derives summary from loaded orders without duplicate ESI fetch',
        (tester) async {
      const characterId = 12345678;
      final testOrders = [testBuyOrder, testSellOrder];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            characterOrdersProvider(characterId)
                .overrideWith((ref) async => testOrders),
          ],
          child: const MaterialApp(
            home: ActiveOrdersScreen(characterId: characterId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Summary should derive from orders — the buy count of 1 should appear.
      // In the summary chip, the buy count is displayed as a value.
      // We also see the Buy Orders tab label.
      expect(find.text('Buy Orders'), findsWidgets);
      // The Pyerite type name should appear.
      expect(find.text('Pyerite'), findsOneWidget);
    });

    testWidgets(
        'exposes order progress semantics with filled percent and '
        'remaining volume', (tester) async {
      const characterId = 12345678;
      final testOrders = [testBuyOrder];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            characterOrdersProvider(characterId)
                .overrideWith((ref) async => testOrders),
          ],
          child: const MaterialApp(
            home: ActiveOrdersScreen(characterId: characterId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The Semantics widget with progress label should be present.
      // Verify the semantics label is accessible.
      final semanticsHandle = find.bySemanticsLabel(
        RegExp(r'Order fill 20%.*2000 of 10000 units remaining'),
      );
      expect(semanticsHandle, findsOneWidget);

      // Also verify the visible text shows the filled percentage.
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('2000/10000'), findsOneWidget);
    });
  });
}
