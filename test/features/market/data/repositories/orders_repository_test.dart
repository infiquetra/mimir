import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/market/data/models/character_order.dart';
import 'package:mimir/features/market/data/repositories/orders_repository.dart';
import 'package:mimir/features/market/presentation/active_orders_screen.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
class MockEsiClient extends Mock implements EsiClient {}

// Helper to create a fake [Character] with minimal required fields.
Character _fakeCharacter({required int characterId, required String name}) {
  return Character(
    characterId: characterId,
    name: name,
    corporationId: 1,
    corporationName: 'Corp',
    portraitUrl: 'https://example.com/portrait.png',
    securityStatus: 0.0,
    tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
    lastUpdated: DateTime.now(),
    isActive: true,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
Map<String, dynamic> _makeBuyJson() => {
      'order_id': 1,
      'type_id': 34,
      'region_id': 10000002,
      'location_id': 60003760,
      'price': 5.67,
      'volume_remain': 450,
      'volume_total': 1000,
      'min_volume': 1,
      'is_buy_order': true,
      'issued': '2024-01-01T00:00:00Z',
      'duration': 90,
      'range': 'region',
      'is_corporation': false,
      'escrow': 2551.5,
    };

Map<String, dynamic> _makeSellJson() => {
      'order_id': 2,
      'type_id': 35,
      'region_id': 10000002,
      'location_id': 60003760,
      'price': 12.34,
      'volume_remain': 100,
      'volume_total': 500,
      'min_volume': 1,
      'is_buy_order': false,
      'issued': '2024-01-02T00:00:00Z',
      'duration': 30,
      'range': 'station',
      'is_corporation': false,
      'escrow': 0.0,
    };

// ---------------------------------------------------------------------------
// Model tests
// ---------------------------------------------------------------------------
void main() {
  group('CharacterOrder', () {
    test('fromJson parses active buy order from ESI payload', () {
      final json = _makeBuyJson();
      final order = CharacterOrder.fromJson(json, characterId: 12345678);

      expect(order.orderId, 1);
      expect(order.characterId, 12345678);
      expect(order.typeId, 34);
      expect(order.typeName, 'Type #34');
      expect(order.regionId, 10000002);
      expect(order.locationId, 60003760);
      expect(order.locationName, 'Location #60003760');
      expect(order.price, 5.67);
      expect(order.volumeRemain, 450);
      expect(order.volumeTotal, 1000);
      expect(order.minVolume, 1);
      expect(order.isBuyOrder, true);
      expect(order.issued, DateTime.parse('2024-01-01T00:00:00Z'));
      expect(order.duration, 90);
      expect(order.range, OrderRange.region);
      expect(order.isCorporation, false);
      expect(order.escrow, 2551.5);
      expect(order.state, OrderState.active);
      expect(order.expires, DateTime.parse('2024-03-31T00:00:00Z'));
      expect(order.fillPercent, 0.55);
      expect(order.remainingValue, closeTo(5.67 * 450, 0.001));
      // The canned order is issued in January 2024, duration 90 days, so it is
      // expired relative to today. Use a fresh order for isActive assertion.
      final freshJson = _makeBuyJson();
      freshJson['issued'] = DateTime.now().toUtc().toIso8601String();
      final freshOrder =
          CharacterOrder.fromJson(freshJson, characterId: 12345678);
      expect(freshOrder.isActive, true);
    });

    test('fromJson coerces numeric int field from double', () {
      final json = _makeBuyJson();
      json['order_id'] = 1.0; // double but integral
      final order = CharacterOrder.fromJson(json, characterId: 1);
      expect(order.orderId, 1);
    });

    test('fromJson coerces double from int', () {
      final json = _makeBuyJson();
      json['price'] = 42; // int for double field
      final order = CharacterOrder.fromJson(json, characterId: 1);
      expect(order.price, 42.0);
    });

    test('fromJson throws FormatException for malformed bool', () {
      final json = _makeBuyJson();
      json['is_buy_order'] = 'true';
      expect(
        () => CharacterOrder.fromJson(json, characterId: 1),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws FormatException for malformed string (range)', () {
      final json = _makeBuyJson();
      json['range'] = 123;
      expect(
        () => CharacterOrder.fromJson(json, characterId: 1),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws FormatException for malformed date', () {
      final json = _makeBuyJson();
      json['issued'] = 'not-a-date';
      expect(
        () => CharacterOrder.fromJson(json, characterId: 1),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws FormatException for missing required field', () {
      final json = _makeBuyJson();
      json.remove('order_id');
      expect(
        () => CharacterOrder.fromJson(json, characterId: 1),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson throws FormatException for unknown range', () {
      final json = _makeBuyJson();
      json['range'] = 'invalid-range';
      expect(
        () => CharacterOrder.fromJson(json, characterId: 12345678),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Invalid market order range'),
          ),
        ),
      );
    });

    test('fromJson throws FormatException for unknown state', () {
      final json = _makeBuyJson();
      json['state'] = 'unknown-state';
      expect(
        () => CharacterOrder.fromJson(json, characterId: 12345678),
        throwsA(isA<FormatException>()),
      );
    });

    test('isExpired is true when order has expired', () {
      final json = {
        'order_id': 3,
        'type_id': 34,
        'region_id': 1,
        'location_id': 1,
        'price': 1.0,
        'volume_remain': 1,
        'volume_total': 10,
        'min_volume': 1,
        'is_buy_order': true,
        'issued': '2000-01-01T00:00:00Z',
        'duration': 1,
        'range': 'station',
        'is_corporation': false,
        'escrow': 0.0,
      };
      final order = CharacterOrder.fromJson(json, characterId: 1);
      expect(order.isExpired, true);
    });

    test('isActive is false when state is not active', () {
      final json = {
        'order_id': 4,
        'type_id': 34,
        'region_id': 1,
        'location_id': 1,
        'price': 1.0,
        'volume_remain': 1,
        'volume_total': 10,
        'min_volume': 1,
        'is_buy_order': true,
        'issued': DateTime.now().toUtc().toIso8601String(),
        'duration': 90,
        'range': 'station',
        'is_corporation': false,
        'escrow': 0.0,
        'state': 'cancelled',
      };
      final order = CharacterOrder.fromJson(json, characterId: 1);
      expect(order.isActive, false);
    });

    test('fillPercent is 0.0 when volumeTotal is zero', () {
      final json = {
        'order_id': 5,
        'type_id': 34,
        'region_id': 1,
        'location_id': 1,
        'price': 1.0,
        'volume_remain': 0,
        'volume_total': 0,
        'min_volume': 1,
        'is_buy_order': true,
        'issued': DateTime.now().toUtc().toIso8601String(),
        'duration': 90,
        'range': 'station',
        'is_corporation': false,
        'escrow': 0.0,
      };
      final order = CharacterOrder.fromJson(json, characterId: 1);
      expect(order.fillPercent, 0.0);
    });

    test('type_name and location_name are used when present', () {
      final json = _makeBuyJson();
      json['type_name'] = 'Tritanium';
      json['location_name'] = 'Jita IV - Moon 4';
      final order = CharacterOrder.fromJson(json, characterId: 1);
      expect(order.typeName, 'Tritanium');
      expect(order.locationName, 'Jita IV - Moon 4');
    });

    test('fallback names are deterministic', () {
      final json = _makeBuyJson();
      final order = CharacterOrder.fromJson(json, characterId: 1);
      expect(order.typeName, 'Type #34');
      expect(order.locationName, 'Location #60003760');
    });
  });

  // -------------------------------------------------------------------------
  // Repository tests
  // -------------------------------------------------------------------------
  group('OrdersRepository', () {
    late MockEsiClient mockEsiClient;
    late OrdersRepository repository;

    setUp(() {
      mockEsiClient = MockEsiClient();
      repository = OrdersRepository(esiClient: mockEsiClient);
      registerFallbackValue(
        RequestOptions(path: '/characters/12345678/orders/'),
      );
    });

    test('getCharacterOrders rejects invalid character id before calling ESI',
        () {
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
      verifyNever(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          any(),
          characterId: any(named: 'characterId'),
        ),
      );
    });

    test(
        'getCharacterOrders fetches active orders from authenticated ESI endpoint',
        () async {
      final sellJson = _makeSellJson();
      final buyJson = _makeBuyJson();

      when(
        () => mockEsiClient.authenticatedGet<dynamic>(
          '/characters/12345678/orders/',
          characterId: 12345678,
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/characters/12345678/orders/'),
          data: [sellJson, buyJson],
        ),
      );

      final orders = await repository.getCharacterOrders(12345678);

      expect(orders, hasLength(2));
      // Buy first, sell second.
      expect(orders[0].isBuyOrder, true);
      expect(orders[1].isBuyOrder, false);
    });

    test(
        'getCharacterOrders returns empty list for successful empty ESI response',
        () async {
      when(
        () => mockEsiClient.authenticatedGet<dynamic>(
          '/characters/12345678/orders/',
          characterId: 12345678,
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/characters/12345678/orders/'),
          data: [],
        ),
      );

      final orders = await repository.getCharacterOrders(12345678);
      expect(orders, isEmpty);
    });

    test('getCharacterOrders rethrows EsiException as EsiException', () async {
      when(
        () => mockEsiClient.authenticatedGet<dynamic>(
          '/characters/12345678/orders/',
          characterId: 12345678,
        ),
      ).thenThrow(
        const EsiException('Forbidden - missing scope', statusCode: 403),
      );

      expect(
        () => repository.getCharacterOrders(12345678),
        throwsA(
          isA<EsiException>().having(
            (e) => e.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });

    test('getCharacterOrders rethrows DioException as DioException', () async {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/characters/12345678/orders/'),
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timeout',
      );
      when(
        () => mockEsiClient.authenticatedGet<dynamic>(
          '/characters/12345678/orders/',
          characterId: 12345678,
        ),
      ).thenThrow(dioException);

      expect(
        () => repository.getCharacterOrders(12345678),
        throwsA(isA<DioException>()),
      );
    });

    test(
        'getCharacterOrders throws FormatException when response data is not a List',
        () async {
      when(
        () => mockEsiClient.authenticatedGet<dynamic>(
          '/characters/12345678/orders/',
          characterId: 12345678,
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/characters/12345678/orders/'),
          data: {'orders': []},
        ),
      );

      expect(
        () => repository.getCharacterOrders(12345678),
        throwsA(isA<FormatException>()),
      );
    });

    test('getCharacterOrders sorts same-side orders by issued descending',
        () async {
      final oldOrder = _makeBuyJson();
      oldOrder['order_id'] = 10;
      oldOrder['issued'] = '2024-01-01T00:00:00Z';

      final newOrder = _makeBuyJson();
      newOrder['order_id'] = 11;
      newOrder['issued'] = '2024-01-05T00:00:00Z';

      when(
        () => mockEsiClient.authenticatedGet<dynamic>(
          '/characters/12345678/orders/',
          characterId: 12345678,
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/characters/12345678/orders/'),
          data: [oldOrder, newOrder],
        ),
      );

      final orders = await repository.getCharacterOrders(12345678);
      expect(orders[0].orderId, 11); // newer first
      expect(orders[1].orderId, 10);
    });

    test('provider coverage: characterOrdersProvider delegates to repository',
        () async {
      final container = ProviderContainer(
        overrides: [
          esiClientProvider.overrideWithValue(mockEsiClient),
        ],
      );
      addTearDown(container.dispose);

      when(
        () => mockEsiClient.authenticatedGet<dynamic>(
          '/characters/12345678/orders/',
          characterId: 12345678,
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/characters/12345678/orders/'),
          data: [_makeBuyJson()],
        ),
      );

      final result = await container.read(
        characterOrdersProvider(12345678).future,
      );
      expect(result, hasLength(1));
    });

    test(
        'getCharacterOrders throws FormatException when an individual item is not a Map',
        () async {
      when(
        () => mockEsiClient.authenticatedGet<dynamic>(
          '/characters/12345678/orders/',
          characterId: 12345678,
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/characters/12345678/orders/'),
          data: ['not-a-map'],
        ),
      );

      expect(
        () => repository.getCharacterOrders(12345678),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Widget tests
  // -------------------------------------------------------------------------
  group('ActiveOrdersScreen', () {
    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    testWidgets('shows no character state without refresh action',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCharacterProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
          ],
          child: const MaterialApp(
            home: ActiveOrdersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Character Selected'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Tooltip &&
              (w.message?.contains('Refresh active market orders') ?? false),
        ),
        findsNothing,
      );
    });

    testWidgets('shows buy and sell tabs with active order cards',
        (tester) async {
      final character = _fakeCharacter(
        characterId: 12345678,
        name: 'Test Pilot',
      );

      final buyOrder = CharacterOrder.fromJson(
        _makeBuyJson(),
        characterId: 12345678,
      );
      final sellOrder = CharacterOrder.fromJson(
        _makeSellJson(),
        characterId: 12345678,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCharacterProvider.overrideWith(
              (ref) => Stream.value(character),
            ),
            characterOrdersProvider(character.characterId).overrideWith(
              (ref) => Future.value([buyOrder, sellOrder]),
            ),
          ],
          child: const MaterialApp(
            home: ActiveOrdersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Buy Orders'), findsOneWidget);
      expect(find.text('Sell Orders'), findsOneWidget);
      expect(find.text(buyOrder.typeName), findsOneWidget);
      expect(find.text(buyOrder.locationName), findsOneWidget);

      // Switch to Sell Orders tab before asserting sell content.
      await tester.tap(find.widgetWithText(Tab, 'Sell Orders'));
      await tester.pumpAndSettle();

      expect(find.text(sellOrder.typeName), findsOneWidget);
      expect(find.text(sellOrder.locationName), findsOneWidget);
    });

    testWidgets('exposes refresh and order semantics', (tester) async {
      final character = _fakeCharacter(
        characterId: 12345678,
        name: 'Test Pilot',
      );

      final buyOrder = CharacterOrder.fromJson(
        _makeBuyJson(),
        characterId: 12345678,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCharacterProvider.overrideWith(
              (ref) => Stream.value(character),
            ),
            characterOrdersProvider(character.characterId).overrideWith(
              (ref) => Future.value([buyOrder]),
            ),
          ],
          child: const MaterialApp(
            home: ActiveOrdersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Refresh tooltip
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == 'Refresh active market orders',
        ),
        findsOneWidget,
      );

      // Order fill progress semantics
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && (w.properties.label == 'Order fill progress'),
        ),
        findsWidgets,
      );

      // Order expiry semantics
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label == 'Order expiry'),
        ),
        findsWidgets,
      );
    });

    testWidgets('shows empty buy state when only sell orders exist',
        (tester) async {
      final character = _fakeCharacter(
        characterId: 12345678,
        name: 'Test Pilot',
      );

      final sellOrder = CharacterOrder.fromJson(
        _makeSellJson(),
        characterId: 12345678,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCharacterProvider.overrideWith(
              (ref) => Stream.value(character),
            ),
            characterOrdersProvider(character.characterId).overrideWith(
              (ref) => Future.value([sellOrder]),
            ),
          ],
          child: const MaterialApp(
            home: ActiveOrdersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buy Orders'));
      await tester.pumpAndSettle();

      expect(find.text('No buy orders'), findsOneWidget);
      expect(find.text('No sell orders'), findsNothing);
    });

    testWidgets('shows empty sell state when only buy orders exist',
        (tester) async {
      final character = _fakeCharacter(
        characterId: 12345678,
        name: 'Test Pilot',
      );

      final buyOrder = CharacterOrder.fromJson(
        _makeBuyJson(),
        characterId: 12345678,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCharacterProvider.overrideWith(
              (ref) => Stream.value(character),
            ),
            characterOrdersProvider(character.characterId).overrideWith(
              (ref) => Future.value([buyOrder]),
            ),
          ],
          child: const MaterialApp(
            home: ActiveOrdersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sell Orders'));
      await tester.pumpAndSettle();

      expect(find.text('No sell orders'), findsOneWidget);
      expect(find.text('No buy orders'), findsNothing);
    });
  });
}
