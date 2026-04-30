import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart' hide UniverseName;
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/market/data/models/character_order.dart';
import 'package:mimir/features/market/data/repositories/orders_repository.dart';
import 'package:mimir/features/market/presentation/active_orders_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockEsiClient extends Mock implements EsiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
  });

  Response<List<dynamic>> makeListResponse(List<dynamic> data,
      {String path = '/characters/1/orders/'}) {
    return Response<List<dynamic>>(
      requestOptions: RequestOptions(path: path),
      data: data,
      statusCode: 200,
    );
  }

  // ── CharacterOrder.fromJson ────────────────────────────────

  group('CharacterOrder.fromJson', () {
    test('parses active ESI order and computes expiration and fill percent',
        () {
      final json = {
        'order_id': 1,
        'type_id': 34,
        'region_id': 10000002,
        'location_id': 60003760,
        'price': 5.67,
        'volume_remain': 25,
        'volume_total': 100,
        'min_volume': 1,
        'is_buy_order': false,
        'issued': '2025-01-15T10:00:00Z',
        'duration': 90,
        'range': 'region',
        'is_corporation': false,
        'escrow': 567.0,
      };

      final order = CharacterOrder.fromJson(json, characterId: 123);

      expect(order.state, OrderState.active);
      expect(order.issued, DateTime.parse('2025-01-15T10:00:00Z'));
      expect(order.expires, order.issued.add(const Duration(days: 90)));
      expect(order.fillPercent, 0.75);
      expect(order.range, OrderRange.region);
      expect(order.isBuyOrder, false);
      expect(order.characterId, 123);
      expect(order.minVolume, 1);
      expect(order.isCorporation, false);
      expect(order.escrow, 567.0);
    });

    test('defaults optional sell-order fields when ESI omits them', () {
      final json = {
        'order_id': 2,
        'type_id': 35,
        'region_id': 10000002,
        'location_id': 60003760,
        'price': 10.0,
        'volume_remain': 50,
        'volume_total': 50,
        'issued': '2025-01-15T10:00:00Z',
        'duration': 30,
        'range': 'station',
      };

      final order = CharacterOrder.fromJson(json, characterId: 123);

      expect(order.isBuyOrder, false);
      expect(order.minVolume, 1);
      expect(order.isCorporation, false);
      expect(order.escrow, null);
      expect(order.state, OrderState.active);
    });

    test('parses all documented numeric active order ranges', () {
      final ranges = {
        '1': OrderRange.reach1,
        '2': OrderRange.reach2,
        '3': OrderRange.reach3,
        '4': OrderRange.reach4,
        '5': OrderRange.reach5,
        '10': OrderRange.reach10,
        '20': OrderRange.reach20,
        '30': OrderRange.reach30,
        '40': OrderRange.reach40,
      };

      for (final entry in ranges.entries) {
        final json = {
          'order_id': 1,
          'type_id': 34,
          'region_id': 10000002,
          'location_id': 60003760,
          'price': 5.0,
          'volume_remain': 1,
          'volume_total': 1,
          'issued': '2025-01-15T10:00:00Z',
          'duration': 1,
          'range': entry.key,
        };
        final order = CharacterOrder.fromJson(json);
        expect(order.range, entry.value, reason: 'range ${entry.key}');
      }
    });

    test('throws FormatException for malformed active order payload', () {
      // Missing required key
      expect(
        () => CharacterOrder.fromJson(<String, dynamic>{
          'type_id': 34,
          'region_id': 10000002,
          'location_id': 60003760,
          'price': 5.0,
          'volume_remain': 1,
          'volume_total': 1,
          'issued': '2025-01-15T10:00:00Z',
          'duration': 1,
          'range': 'station',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('order_id'),
          ),
        ),
      );

      // Wrong type for required key
      expect(
        () => CharacterOrder.fromJson(<String, dynamic>{
          'order_id': 1,
          'type_id': 34,
          'region_id': 10000002,
          'location_id': 60003760,
          'price': 'cheap',
          'volume_remain': 1,
          'volume_total': 1,
          'issued': '2025-01-15T10:00:00Z',
          'duration': 1,
          'range': 'station',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('price'),
          ),
        ),
      );

      // Wrong type for present optional key (is_buy_order)
      expect(
        () => CharacterOrder.fromJson(<String, dynamic>{
          'order_id': 1,
          'type_id': 34,
          'region_id': 10000002,
          'location_id': 60003760,
          'price': 5.0,
          'volume_remain': 1,
          'volume_total': 1,
          'is_buy_order': 'yes',
          'issued': '2025-01-15T10:00:00Z',
          'duration': 1,
          'range': 'station',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('is_buy_order'),
          ),
        ),
      );

      // Wrong type for present optional key (is_corporation)
      expect(
        () => CharacterOrder.fromJson(<String, dynamic>{
          'order_id': 1,
          'type_id': 34,
          'region_id': 10000002,
          'location_id': 60003760,
          'price': 5.0,
          'volume_remain': 1,
          'volume_total': 1,
          'issued': '2025-01-15T10:00:00Z',
          'duration': 1,
          'range': 'station',
          'is_corporation': 'yes',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('is_corporation'),
          ),
        ),
      );

      // Wrong type for present optional key (min_volume)
      expect(
        () => CharacterOrder.fromJson(<String, dynamic>{
          'order_id': 1,
          'type_id': 34,
          'region_id': 10000002,
          'location_id': 60003760,
          'price': 5.0,
          'volume_remain': 1,
          'volume_total': 1,
          'issued': '2025-01-15T10:00:00Z',
          'duration': 1,
          'range': 'station',
          'min_volume': 'one',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('min_volume'),
          ),
        ),
      );

      // Wrong type for present optional key (escrow)
      expect(
        () => CharacterOrder.fromJson(<String, dynamic>{
          'order_id': 1,
          'type_id': 34,
          'region_id': 10000002,
          'location_id': 60003760,
          'price': 5.0,
          'volume_remain': 1,
          'volume_total': 1,
          'issued': '2025-01-15T10:00:00Z',
          'duration': 1,
          'range': 'station',
          'escrow': 'fifty',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('escrow'),
          ),
        ),
      );
    });
  });

  // ── OrdersRepository.getActiveOrders ──────────────────────

  group('OrdersRepository.getActiveOrders', () {
    const characterId = 12345678;
    late MockEsiClient mockEsiClient;
    late OrdersRepository repository;

    setUp(() {
      mockEsiClient = MockEsiClient();
      repository = OrdersRepository(esiClient: mockEsiClient);
      reset(mockEsiClient);
    });

    test(
        'returns active orders with resolved type and location names sorted newest first',
        () async {
      final olderOrder = {
        'order_id': 1,
        'type_id': 34,
        'region_id': 10000002,
        'location_id': 60003760,
        'price': 5.0,
        'volume_remain': 25,
        'volume_total': 100,
        'min_volume': 1,
        'is_buy_order': false,
        'issued': '2025-01-10T10:00:00Z',
        'duration': 90,
        'range': 'region',
      };
      final newerOrder = {
        'order_id': 2,
        'type_id': 35,
        'region_id': 10000002,
        'location_id': 60003761,
        'price': 10.0,
        'volume_remain': 10,
        'volume_total': 50,
        'min_volume': 1,
        'is_buy_order': true,
        'issued': '2025-01-15T10:00:00Z',
        'duration': 30,
        'range': 'station',
      };

      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenAnswer(
        (_) async => makeListResponse([olderOrder, newerOrder]),
      );

      when(
        () => mockEsiClient.getUniverseNames(any()),
      ).thenAnswer(
        (_) async => [
          UniverseName(id: 34, name: 'Tritanium', category: 'inventory_type'),
          UniverseName(id: 35, name: 'Pyerite', category: 'inventory_type'),
          UniverseName(
            id: 60003760,
            name: 'Jita IV - Moon 4',
            category: 'station',
          ),
          UniverseName(
            id: 60003761,
            name: 'Perimeter - Tranquility',
            category: 'station',
          ),
        ],
      );

      final orders = await repository.getActiveOrders(characterId);

      expect(orders.length, 2);
      expect(orders.first.orderId, 2); // newest first
      expect(orders.first.typeName, 'Pyerite');
      expect(orders.first.locationName, 'Perimeter - Tranquility');
      expect(orders.first.isBuyOrder, true);
      expect(orders.first.characterId, characterId);

      expect(orders.last.orderId, 1);
      expect(orders.last.typeName, 'Tritanium');
      expect(orders.last.locationName, 'Jita IV - Moon 4');
      expect(orders.last.isBuyOrder, false);
    });

    test(
        'returns empty list and skips name resolution when ESI returns no active orders',
        () async {
      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenAnswer(
        (_) async => makeListResponse([]),
      );

      final orders = await repository.getActiveOrders(characterId);

      expect(orders, isEmpty);
      verifyNever(() => mockEsiClient.getUniverseNames(any()));
    });

    test('throws FormatException when response data is not a list', () async {
      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions:
              RequestOptions(path: '/characters/$characterId/orders/'),
          data: null,
          statusCode: 200,
        ),
      );

      expect(
        () => repository.getActiveOrders(characterId),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when a list element is not a map', () async {
      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions:
              RequestOptions(path: '/characters/$characterId/orders/'),
          data: ['not-a-map'],
          statusCode: 200,
        ),
      );

      expect(
        () => repository.getActiveOrders(characterId),
        throwsA(isA<FormatException>()),
      );
    });

    test('ordersRepositoryProvider builds with real dependencies', () {
      final mockClient = MockEsiClient();
      final container = ProviderContainer(
        overrides: [
          esiClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);
      expect(
        () => container.read(ordersRepositoryProvider),
        returnsNormally,
      );
    });

    test('rethrows EsiException when active orders request fails', () async {
      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenThrow(
        const EsiException('Forbidden - missing scope', statusCode: 403),
      );

      expect(
        () => repository.getActiveOrders(characterId),
        throwsA(
          isA<EsiException>().having(
            (e) => e.isScopeError,
            'isScopeError',
            true,
          ),
        ),
      );
    });

    test('rethrows EsiException when universe names request fails', () async {
      final orderJson = {
        'order_id': 1,
        'type_id': 34,
        'region_id': 10000002,
        'location_id': 60003760,
        'price': 5.0,
        'volume_remain': 25,
        'volume_total': 100,
        'issued': '2025-01-15T10:00:00Z',
        'duration': 90,
        'range': 'region',
      };

      when(
        () => mockEsiClient.authenticatedGet<List<dynamic>>(
          '/characters/$characterId/orders/',
          characterId: characterId,
        ),
      ).thenAnswer(
        (_) async => makeListResponse([orderJson]),
      );

      when(
        () => mockEsiClient.getUniverseNames(any()),
      ).thenThrow(
        const EsiException('Service Unavailable', statusCode: 503),
      );

      expect(
        () => repository.getActiveOrders(characterId),
        throwsA(
          isA<EsiException>().having(
            (e) => e.isServerError,
            'isServerError',
            true,
          ),
        ),
      );
    });
  });

  // ── Additional model tests ─────────────────────────────────

  group('CharacterOrder getters', () {
    test('isExpired returns true when order has expired', () {
      final order = CharacterOrder(
        orderId: 1,
        characterId: 1,
        typeId: 34,
        typeName: 'Tritanium',
        regionId: 10000002,
        locationId: 60003760,
        locationName: 'Jita',
        price: 5.0,
        volumeRemain: 0,
        volumeTotal: 100,
        minVolume: 1,
        isBuyOrder: false,
        issued: DateTime.now().subtract(const Duration(days: 100)),
        duration: 1,
        range: OrderRange.station,
        isCorporation: false,
        escrow: null,
        state: OrderState.active,
      );

      expect(order.isExpired, true);
      expect(order.fillPercent, 1.0);
    });

    test('fillPercent returns 0 when volumeTotal is 0', () {
      final order = CharacterOrder(
        orderId: 1,
        characterId: 1,
        typeId: 34,
        typeName: 'Tritanium',
        regionId: 10000002,
        locationId: 60003760,
        locationName: 'Jita',
        price: 5.0,
        volumeRemain: 0,
        volumeTotal: 0,
        minVolume: 1,
        isBuyOrder: false,
        issued: DateTime.now(),
        duration: 1,
        range: OrderRange.station,
        isCorporation: false,
        escrow: null,
        state: OrderState.active,
      );

      expect(order.fillPercent, 0.0);
    });

    test('copyWithResolvedNames updates type and location names', () {
      final order = CharacterOrder(
        orderId: 1,
        characterId: 1,
        typeId: 34,
        typeName: 'Type 34',
        regionId: 10000002,
        locationId: 60003760,
        locationName: 'Location 60003760',
        price: 5.0,
        volumeRemain: 10,
        volumeTotal: 100,
        minVolume: 1,
        isBuyOrder: false,
        issued: DateTime.now(),
        duration: 1,
        range: OrderRange.station,
        isCorporation: false,
        escrow: null,
        state: OrderState.active,
      );

      final updated = order.copyWithResolvedNames(
        typeName: 'Tritanium',
        locationName: 'Jita IV - Moon 4',
      );

      expect(updated.typeName, 'Tritanium');
      expect(updated.locationName, 'Jita IV - Moon 4');
      expect(updated.orderId, order.orderId);
      expect(updated.price, order.price);
    });
  });

  // ── ActiveOrdersScreen ─────────────────────────────────────

  group('ActiveOrdersScreen', () {
    final testCharacter = Character(
      characterId: 123,
      name: 'Test Character',
      corporationId: 1,
      corporationName: 'Test Corp',
      securityStatus: 0.0,
      portraitUrl: '',
      tokenExpiry: DateTime.now(),
      lastUpdated: DateTime.now(),
      isActive: true,
    );

    testWidgets('shows no-character empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCharacterProvider.overrideWith(
              (ref) => Stream<Character?>.value(null),
            ),
          ],
          child: const MaterialApp(home: ActiveOrdersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Character Selected'), findsOneWidget);
      expect(
        find.text('Add a character to view active market orders.'),
        findsOneWidget,
      );
    });

    testWidgets('shows loading state', (tester) async {
      final completer = Completer<List<CharacterOrder>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCharacterProvider.overrideWith(
              (ref) => Stream<Character?>.value(testCharacter),
            ),
            activeOrdersProvider.overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(home: ActiveOrdersScreen()),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows active order text', (tester) async {
      final order = CharacterOrder(
        orderId: 1,
        characterId: 123,
        typeId: 34,
        typeName: 'Tritanium',
        regionId: 10000002,
        locationId: 60003760,
        locationName: 'Jita IV - Moon 4',
        price: 5.67,
        volumeRemain: 25,
        volumeTotal: 100,
        minVolume: 1,
        isBuyOrder: false,
        issued: DateTime.parse('2025-01-15T10:00:00Z'),
        duration: 90,
        range: OrderRange.region,
        isCorporation: false,
        escrow: 567.0,
        state: OrderState.active,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCharacterProvider.overrideWith(
              (ref) => Stream<Character?>.value(testCharacter),
            ),
            activeOrdersProvider.overrideWith(
              (ref) => Future.value([order]),
            ),
          ],
          child: const MaterialApp(home: ActiveOrdersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sell'), findsOneWidget);
      expect(find.text('Tritanium'), findsOneWidget);
      expect(find.text('Jita IV - Moon 4'), findsOneWidget);
    });

    testWidgets('shows orders empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCharacterProvider.overrideWith(
              (ref) => Stream<Character?>.value(testCharacter),
            ),
            activeOrdersProvider.overrideWith(
              (ref) => Future.value([]),
            ),
          ],
          child: const MaterialApp(home: ActiveOrdersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Active Orders'), findsOneWidget);
      expect(
        find.text('This character has no active market orders.'),
        findsOneWidget,
      );
    });

    testWidgets('shows orders error state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCharacterProvider.overrideWith(
              (ref) => Stream<Character?>.value(testCharacter),
            ),
            activeOrdersProvider.overrideWith(
              (ref) => Future.error(Exception('Network down')),
            ),
          ],
          child: const MaterialApp(home: ActiveOrdersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to Load Orders'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows character error state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCharacterProvider.overrideWith(
              (ref) => Stream<Character?>.error(Exception('DB error')),
            ),
          ],
          child: const MaterialApp(home: ActiveOrdersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to Load Character'), findsOneWidget);
    });
  });
}
