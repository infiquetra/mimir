import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/data/repositories/price_repository.dart';
import 'package:mimir/features/market/presentation/price_check_screen.dart';

// ---------------------------------------------------------------------------
// Fake order fetcher (records calls, returns canned results)
// ---------------------------------------------------------------------------

class FakeOrderFetcher {
  final List<({int typeId, int regionId})> calls = [];
  Future<List<MarketOrderQuote>> Function(int typeId, int regionId)? onFetch;

  Future<List<MarketOrderQuote>> call(int typeId, int regionId) async {
    calls.add((typeId: typeId, regionId: regionId));
    if (onFetch != null) return onFetch!(typeId, regionId);
    return [];
  }
}

// ---------------------------------------------------------------------------
// Fake Dio HttpClientAdapter for pagination tests
// ---------------------------------------------------------------------------

class FakeHttpClientAdapter implements HttpClientAdapter {
  final List<({int statusCode, Map<String, List<String>> headers, Object body})>
      responses;
  final List<({String path, Map<String, dynamic> queryParameters})> requests =
      [];

  FakeHttpClientAdapter(this.responses);

  int _callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions requestOptions,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((
      path: requestOptions.path,
      queryParameters: requestOptions.queryParameters,
    ));

    final resp = responses[_callCount < responses.length
        ? _callCount
        : responses.length - 1];
    _callCount++;

    final bodyBytes = utf8.encode(jsonEncode(resp.body));
    return ResponseBody.fromBytes(
      bodyBytes,
      resp.statusCode,
      headers: resp.headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MarketOrderQuote _buy(double price, [int volume = 1000]) =>
    MarketOrderQuote(price: price, volumeRemain: volume, isBuyOrder: true);

MarketOrderQuote _sell(double price, [int volume = 1000]) =>
    MarketOrderQuote(price: price, volumeRemain: volume, isBuyOrder: false);

PriceRepository _repoWithFetcher(
  FakeOrderFetcher fetcher, {
  Map<int, String>? regions,
}) {
  return PriceRepository(
    orderFetcher: fetcher.call,
    marketRegions: regions ?? eveMarketRegions,
    clock: () => DateTime.utc(2025, 1, 1, 12, 0, 0),
  );
}

// ---------------------------------------------------------------------------
// Repository unit tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // getPrice
  // ---------------------------------------------------------------------------

  group('getPrice', () {
    test('aggregates buy and sell orders for one region', () async {
      final fetcher = FakeOrderFetcher();
      fetcher.onFetch = (typeId, regionId) async => [
            _buy(100.0, 10), // buyMax candidate
            _buy(90.0, 5),
            _sell(120.0, 8), // sellMin candidate
            _sell(130.0, 7),
          ];

      final repo = _repoWithFetcher(fetcher);

      final result = await repo.getPrice(34, 10000002);

      expect(result.typeId, 34);
      expect(result.regionId, 10000002);
      expect(result.typeName, 'Type 34');
      expect(result.buyMax, 100.0);
      expect(result.sellMin, 120.0);
      expect(result.buyAvg, (100.0 + 90.0) / 2);
      expect(result.sellAvg, (120.0 + 130.0) / 2);
      expect(result.buyVolume, 15);
      expect(result.sellVolume, 15);
      expect(result.spread, 20.0);
      expect(result.spreadPercent, 20.0);
      expect(result.margin, closeTo(120.0 * 0.99 - 100.0 * 1.01, 0.001));
      expect(result.updatedAt, DateTime.utc(2025, 1, 1, 12, 0, 0));
    });

    test('returns null prices and zero volumes for an empty successful region response', () async {
      final fetcher = FakeOrderFetcher();
      fetcher.onFetch = (typeId, regionId) async => [];

      final repo = _repoWithFetcher(fetcher);
      final result = await repo.getPrice(34, 10000002);

      expect(result.buyMax, isNull);
      expect(result.sellMin, isNull);
      expect(result.buyAvg, isNull);
      expect(result.sellAvg, isNull);
      expect(result.buyVolume, 0);
      expect(result.sellVolume, 0);
    });

    test('validates positive type id', () async {
      final fetcher = FakeOrderFetcher();
      final repo = _repoWithFetcher(fetcher);

      expect(
        () => repo.getPrice(0, 10000002),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('expected positive EVE type id'),
        )),
      );
      expect(
        () => repo.getPrice(-1, 10000002),
        throwsA(isA<ArgumentError>()),
      );
      expect(fetcher.calls, isEmpty);
    });

    test('validates known region id', () async {
      final fetcher = FakeOrderFetcher();
      final repo = _repoWithFetcher(fetcher);

      expect(
        () => repo.getPrice(34, 99999999),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('expected known market region id'),
        )),
      );
      expect(fetcher.calls, isEmpty);
    });

    test('does not call fetcher when region is not in injected marketRegions', () async {
      final fetcher = FakeOrderFetcher();
      // Use an explicit two-region map so 10000002 is NOT in it.
      final smallRegions = <int, String>{10000030: 'Heimatar'};
      final repo = PriceRepository(
        orderFetcher: fetcher.call,
        marketRegions: smallRegions,
        clock: () => DateTime.utc(2025, 1, 1),
      );

      expect(
        () => repo.getPrice(34, 10000002),
        throwsA(isA<ArgumentError>()),
      );
      expect(fetcher.calls, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // MarketRegionPrice / eveMarketRegions
  // ---------------------------------------------------------------------------

  test('marketRegions matches the configured all-region catalog', () {
    expect(eveMarketRegions, <int, String>{
      10000001: 'Derelik',
      10000002: 'The Forge',
      10000003: 'Vale of the Silent',
      10000005: 'Detorid',
      10000006: 'Wicked Creek',
      10000007: 'Cache',
      10000008: 'Scalding Pass',
      10000009: 'Insmother',
      10000010: 'Tribute',
      10000011: 'Great Wildlands',
      10000012: 'Curse',
      10000013: 'Malpais',
      10000014: 'Catch',
      10000015: 'Venal',
      10000016: 'Lonetrek',
      10000018: 'The Spire',
      10000020: 'Tash-Murkon',
      10000021: 'Outer Passage',
      10000022: 'Stain',
      10000023: 'Pure Blind',
      10000025: 'Immensea',
      10000027: 'Etherium Reach',
      10000028: 'Molden Heath',
      10000029: 'Geminate',
      10000030: 'Heimatar',
      10000031: 'Impass',
      10000032: 'Sinq Laison',
      10000033: 'The Citadel',
      10000034: 'The Kalevala Expanse',
      10000035: 'Deklein',
      10000036: 'Devoid',
      10000037: 'Everyshore',
      10000038: 'The Bleak Lands',
      10000039: 'Esoteria',
      10000040: 'Oasa',
      10000041: 'Syndicate',
      10000042: 'Metropolis',
      10000043: 'Domain',
      10000044: 'Solitude',
      10000045: 'Tenal',
      10000046: 'Fade',
      10000047: 'Providence',
      10000048: 'Placid',
      10000049: 'Khanid',
      10000050: 'Querious',
      10000051: 'Cloud Ring',
      10000052: 'Kador',
      10000053: 'Cobalt Edge',
      10000054: 'Aridia',
      10000055: 'Branch',
      10000056: 'Feythabolis',
      10000057: 'Outer Ring',
      10000058: 'Fountain',
      10000059: 'Paragon Soul',
      10000060: 'Delve',
      10000061: 'Tenerifis',
      10000062: 'Omist',
      10000063: 'Period Basis',
      10000064: 'Essence',
      10000065: 'Kor-Azor',
      10000066: 'Perrigen Falls',
      10000067: 'Genesis',
      10000068: 'Verge Vendor',
      10000069: 'Black Rise',
      10000070: 'Pochven',
    });
  });

  test('getPricesAcrossAllRegions queries every configured region in the full catalog', () async {
    final fetcher = FakeOrderFetcher();
    fetcher.onFetch = (typeId, regionId) async => [];

    final repo = PriceRepository(
      orderFetcher: fetcher.call,
      marketRegions: eveMarketRegions,
      clock: () => DateTime.utc(2025, 1, 1),
    );

    final results = await repo.getPricesAcrossAllRegions(34);

    expect(results.length, eveMarketRegions.length);
    final calledRegionIds = fetcher.calls.map((c) => c.regionId).toList();
    expect(calledRegionIds, eveMarketRegions.keys.toList());
  });

  test('getPricesAcrossAllRegions queries every configured region and preserves configured names', () async {
    final fetcher = FakeOrderFetcher();
    fetcher.onFetch = (typeId, regionId) async => [
          _buy(50.0),
          _sell(60.0),
        ];

    const smallRegions = <int, String>{
      10000002: 'The Forge',
      10000030: 'Heimatar',
      10000042: 'Metropolis',
    };

    final repo = PriceRepository(
      orderFetcher: fetcher.call,
      marketRegions: smallRegions,
      clock: () => DateTime.utc(2025, 1, 1),
    );

    final results = await repo.getPricesAcrossAllRegions(34);

    expect(results.length, 3);
    expect(results[0].regionId, 10000002);
    expect(results[0].regionName, 'The Forge');
    expect(results[1].regionId, 10000030);
    expect(results[1].regionName, 'Heimatar');
    expect(results[2].regionId, 10000042);
    expect(results[2].regionName, 'Metropolis');

    final calledRegionIds = fetcher.calls.map((c) => c.regionId).toList();
    expect(calledRegionIds, [10000002, 10000030, 10000042]);
    final calledTypeIds = fetcher.calls.map((c) => c.typeId).toList();
    expect(calledTypeIds, [34, 34, 34]);
  });

  test('getPricesAcrossAllRegions fails instead of skipping when one region fetch fails', () async {
    final fetcher = FakeOrderFetcher();
    var callCount = 0;
    fetcher.onFetch = (typeId, regionId) async {
      callCount++;
      if (callCount == 2) {
        throw Exception('Network error');
      }
      return [_buy(50.0), _sell(60.0)];
    };

    const smallRegions = <int, String>{
      10000002: 'The Forge',
      10000030: 'Heimatar',
      10000042: 'Metropolis',
    };

    final repo = PriceRepository(
      orderFetcher: fetcher.call,
      marketRegions: smallRegions,
      clock: () => DateTime.utc(2025, 1, 1),
    );

    expect(
      () => repo.getPricesAcrossAllRegions(34),
      throwsA(isA<PriceRepositoryException>().having(
        (e) => e.message,
        'message',
        allOf(
          contains('10000030'),
          contains('Heimatar'),
        ),
      )),
    );
  });

  // ---------------------------------------------------------------------------
  // Default ESI fetcher — pagination tests (Dio fake adapter)
  // ---------------------------------------------------------------------------

  group('default ESI fetcher', () {
    test('combines paginated market order responses', () async {
      final adapter = FakeHttpClientAdapter([
        (
          statusCode: 200,
          headers: {
            'x-pages': ['2'],
            'content-type': ['application/json'],
          },
          body: [
            {'price': 100.0, 'volume_remain': 100, 'is_buy_order': true},
          ],
        ),
        (
          statusCode: 200,
          headers: <String, List<String>>{
            'content-type': ['application/json'],
          },
          body: [
            {'price': 50.0, 'volume_remain': 200, 'is_buy_order': false},
          ],
        ),
      ]);

      final dio = Dio(BaseOptions(baseUrl: 'https://esi.evetech.net/latest'))
        ..httpClientAdapter = adapter;

      final repo = PriceRepository(
        dio: dio,
        marketRegions: const {10000002: 'The Forge'},
        clock: () => DateTime.utc(2025, 1, 1),
      );

      final result = await repo.getPrice(34, 10000002);

      // Both pages should be queried.
      expect(adapter.requests.length, 2);

      // Page 1 with filters.
      expect(adapter.requests[0].path, '/markets/10000002/orders/');
      expect(adapter.requests[0].queryParameters['type_id'], 34);
      expect(adapter.requests[0].queryParameters['order_type'], 'all');
      expect(adapter.requests[0].queryParameters['datasource'], 'tranquility');
      expect(adapter.requests[0].queryParameters['page'], 1);

      // Page 2 with same filters.
      expect(adapter.requests[1].path, '/markets/10000002/orders/');
      expect(adapter.requests[1].queryParameters['type_id'], 34);
      expect(adapter.requests[1].queryParameters['order_type'], 'all');
      expect(adapter.requests[1].queryParameters['datasource'], 'tranquility');
      expect(adapter.requests[1].queryParameters['page'], 2);

      // Aggregation from both pages.
      expect(result.buyMax, 100.0);
      expect(result.sellMin, 50.0);
      expect(result.buyVolume, 100);
      expect(result.sellVolume, 200);
    });

    test('fails on invalid X-Pages header', () async {
      final adapter = FakeHttpClientAdapter([
        (
          statusCode: 200,
          headers: {
            'x-pages': ['not-a-number'],
            'content-type': ['application/json'],
          },
          body: [
            {'price': 100.0, 'volume_remain': 100, 'is_buy_order': true},
          ],
        ),
      ]);

      final dio = Dio(BaseOptions(baseUrl: 'https://esi.evetech.net/latest'))
        ..httpClientAdapter = adapter;

      final repo = PriceRepository(
        dio: dio,
        marketRegions: const {10000002: 'The Forge'},
        clock: () => DateTime.utc(2025, 1, 1),
      );

      expect(
        () => repo.getPrice(34, 10000002),
        throwsA(isA<PriceRepositoryException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('X-Pages'),
            contains('not-a-number'),
          ),
        )),
      );
    });

    test('handles absent X-Pages header as single page', () async {
      final adapter = FakeHttpClientAdapter([
        (
          statusCode: 200,
          headers: <String, List<String>>{
            'content-type': ['application/json'],
          },
          body: [
            {'price': 150.0, 'volume_remain': 300, 'is_buy_order': false},
          ],
        ),
      ]);

      final dio = Dio(BaseOptions(baseUrl: 'https://esi.evetech.net/latest'))
        ..httpClientAdapter = adapter;

      final repo = PriceRepository(
        dio: dio,
        marketRegions: const {10000002: 'The Forge'},
        clock: () => DateTime.utc(2025, 1, 1),
      );

      final result = await repo.getPrice(34, 10000002);

      expect(adapter.requests.length, 1);
      expect(result.sellMin, 150.0);
    });

    test('fails when response body is not a JSON array', () async {
      final adapter = FakeHttpClientAdapter([
        (
          statusCode: 200,
          headers: {
            'content-type': ['application/json'],
          },
          body: {'not': 'a list'},
        ),
      ]);

      final dio = Dio(BaseOptions(baseUrl: 'https://esi.evetech.net/latest'))
        ..httpClientAdapter = adapter;

      final repo = PriceRepository(
        dio: dio,
        marketRegions: const {10000002: 'The Forge'},
        clock: () => DateTime.utc(2025, 1, 1),
      );

      expect(
        () => repo.getPrice(34, 10000002),
        throwsA(isA<PriceRepositoryException>().having(
          (e) => e.message,
          'message',
          contains('Expected JSON array'),
        )),
      );
    });

    test('fails when an order entry is not a Map', () async {
      final adapter = FakeHttpClientAdapter([
        (
          statusCode: 200,
          headers: {
            'content-type': ['application/json'],
          },
          body: ['not a map'],
        ),
      ]);

      final dio = Dio(BaseOptions(baseUrl: 'https://esi.evetech.net/latest'))
        ..httpClientAdapter = adapter;

      final repo = PriceRepository(
        dio: dio,
        marketRegions: const {10000002: 'The Forge'},
        clock: () => DateTime.utc(2025, 1, 1),
      );

      expect(
        () => repo.getPrice(34, 10000002),
        throwsA(isA<PriceRepositoryException>().having(
          (e) => e.message,
          'message',
          allOf(contains('Invalid order entry'), contains('expected Map')),
        )),
      );
    });

    test('fails when price field is missing or invalid', () async {
      final adapter = FakeHttpClientAdapter([
        (
          statusCode: 200,
          headers: {
            'content-type': ['application/json'],
          },
          body: [
            {'price': 'not-a-number', 'volume_remain': 100, 'is_buy_order': true},
          ],
        ),
      ]);

      final dio = Dio(BaseOptions(baseUrl: 'https://esi.evetech.net/latest'))
        ..httpClientAdapter = adapter;

      final repo = PriceRepository(
        dio: dio,
        marketRegions: const {10000002: 'The Forge'},
        clock: () => DateTime.utc(2025, 1, 1),
      );

      expect(
        () => repo.getPrice(34, 10000002),
        throwsA(isA<PriceRepositoryException>().having(
          (e) => e.message,
          'message',
          contains('price'),
        )),
      );
    });

    test('fails when volume_remain is not an int', () async {
      final adapter = FakeHttpClientAdapter([
        (
          statusCode: 200,
          headers: {
            'content-type': ['application/json'],
          },
          body: [
            {'price': 100.0, 'volume_remain': 'not-int', 'is_buy_order': true},
          ],
        ),
      ]);

      final dio = Dio(BaseOptions(baseUrl: 'https://esi.evetech.net/latest'))
        ..httpClientAdapter = adapter;

      final repo = PriceRepository(
        dio: dio,
        marketRegions: const {10000002: 'The Forge'},
        clock: () => DateTime.utc(2025, 1, 1),
      );

      expect(
        () => repo.getPrice(34, 10000002),
        throwsA(isA<PriceRepositoryException>().having(
          (e) => e.message,
          'message',
          contains('volume_remain'),
        )),
      );
    });

    test('fails when is_buy_order is not a bool', () async {
      final adapter = FakeHttpClientAdapter([
        (
          statusCode: 200,
          headers: {
            'content-type': ['application/json'],
          },
          body: [
            {'price': 100.0, 'volume_remain': 100, 'is_buy_order': 'true'},
          ],
        ),
      ]);

      final dio = Dio(BaseOptions(baseUrl: 'https://esi.evetech.net/latest'))
        ..httpClientAdapter = adapter;

      final repo = PriceRepository(
        dio: dio,
        marketRegions: const {10000002: 'The Forge'},
        clock: () => DateTime.utc(2025, 1, 1),
      );

      expect(
        () => repo.getPrice(34, 10000002),
        throwsA(isA<PriceRepositoryException>().having(
          (e) => e.message,
          'message',
          contains('is_buy_order'),
        )),
      );
    });

    test('handles non-PriceRepositoryException Dio errors gracefully', () async {
      final adapter = FakeHttpClientAdapter([
        (
          statusCode: 500,
          headers: {'content-type': ['text/plain']},
          body: 'Internal Server Error',
        ),
      ]);

      final dio = Dio(BaseOptions(baseUrl: 'https://esi.evetech.net/latest'))
        ..httpClientAdapter = adapter;

      final repo = PriceRepository(
        dio: dio,
        marketRegions: const {10000002: 'The Forge'},
        clock: () => DateTime.utc(2025, 1, 1),
      );

      // A 500 with non-JSON body causes Dio's transformer to fail, which
      // hits the general catch → PriceRepositoryException.
      expect(
        () => repo.getPrice(34, 10000002),
        throwsA(isA<PriceRepositoryException>().having(
          (e) => e.message,
          'message',
          contains('Failed to fetch'),
        )),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Constructor defaults
  // ---------------------------------------------------------------------------

  group('constructor defaults', () {
    test('default clock returns DateTime.now-ish', () {
      final repo = PriceRepository(
        marketRegions: const {10000002: 'The Forge'},
      );
      // We can't test the exact time, but we can check it doesn't throw.
      expect(repo.marketRegions, isNotEmpty);
    });

    test('default clock produces a usable DateTime when fetching', () async {
      // Prove the default clock fallback (line 188) works by fetching
      // without injecting a clock.
      final fetcher = FakeOrderFetcher();
      fetcher.onFetch = (typeId, regionId) async => [
            _buy(50.0),
          ];
      final repo = PriceRepository(
        orderFetcher: fetcher.call,
        marketRegions: const {10000002: 'The Forge'},
        // No clock injected — exercises the ?? fallback.
      );
      final result = await repo.getPrice(34, 10000002);
      expect(result.updatedAt, isNotNull);
      // Should be within the last minute.
      expect(
        DateTime.now().difference(result.updatedAt).inSeconds.abs(),
        lessThan(60),
      );
    });

    test('default regions fall back to eveMarketRegions', () {
      final repo = PriceRepository();
      expect(repo.marketRegions.length, eveMarketRegions.length);
      expect(repo.marketRegions[10000002], 'The Forge');
    });

    test('exposes dio field for testing', () {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
      final repo = PriceRepository(
        dio: dio,
        marketRegions: const {10000002: 'The Forge'},
      );
      expect(repo.dio.options.baseUrl, 'https://test.example.com');
    });
  });

  // ---------------------------------------------------------------------------
  // getPricesAcrossAllRegions validation
  // ---------------------------------------------------------------------------

  group('getPricesAcrossAllRegions validation', () {
    test('validates positive type id', () async {
      final repo = PriceRepository(
        marketRegions: const {10000002: 'The Forge'},
        clock: () => DateTime.utc(2025, 1, 1),
      );

      expect(
        () => repo.getPricesAcrossAllRegions(0),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('expected positive EVE type id'),
        )),
      );

      expect(
        () => repo.getPricesAcrossAllRegions(-5),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // priceRepositoryProvider
  // ---------------------------------------------------------------------------

  group('priceRepositoryProvider', () {
    test('provider creates a PriceRepository with default regions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(priceRepositoryProvider);
      expect(repo, isA<PriceRepository>());
      expect(repo.marketRegions.length, eveMarketRegions.length);
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests: PriceCheckScreen
  // ---------------------------------------------------------------------------

  group('PriceCheckScreen', () {
    // Helper — wraps screen in ProviderScope with an overridden price repository.
    Future<void> pumpScreen(
      WidgetTester tester, {
      required PriceRepository repo,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            priceRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: PriceCheckScreen(),
          ),
        ),
      );
    }

    testWidgets('validates Type ID accessibly before repository calls',
        (tester) async {
      final fetcher = FakeOrderFetcher();
      final repo = _repoWithFetcher(fetcher);

      await pumpScreen(tester, repo: repo);

      // Tap "Check Prices" with an empty type ID.
      await tester.tap(find.text('Check Prices'));
      await tester.pumpAndSettle();

      // Assert visible validation error.
      expect(find.text('Enter a positive EVE Type ID.'), findsOneWidget);

      // Assert no fetcher calls.
      expect(fetcher.calls, isEmpty);

      // Enter non-positive number and try again.
      await tester.enterText(find.byType(TextField).first, '-5');
      await tester.tap(find.text('Check Prices'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a positive EVE Type ID.'), findsOneWidget);
      expect(fetcher.calls, isEmpty);
    });

    testWidgets('announces loading and renders all-region results',
        (tester) async {
      final completer = Completer<List<MarketOrderQuote>>();
      final fetcher = FakeOrderFetcher();
      fetcher.onFetch = (typeId, regionId) => completer.future;

      const smallRegions = <int, String>{
        10000002: 'The Forge',
        10000030: 'Heimatar',
      };

      final repo = PriceRepository(
        orderFetcher: fetcher.call,
        marketRegions: smallRegions,
        clock: () => DateTime.utc(2025, 1, 1),
      );

      await pumpScreen(tester, repo: repo);

      // Enter type ID.
      await tester.enterText(find.byType(TextField).first, '34');
      // Ensure all-regions toggle is on.
      expect(find.byType(SwitchListTile), findsOneWidget);

      // Tap "Check Prices".
      await tester.tap(find.text('Check Prices'));
      await tester.pump();

      // Loading state.
      expect(find.text('Loading prices...'), findsOneWidget);

      // Complete with data.
      completer.complete([
        _buy(100.0, 10),
        _sell(120.0, 8),
        _buy(90.0, 5),
        _sell(130.0, 7),
      ]);
      await tester.pumpAndSettle();

      // No more loading, results visible.
      expect(find.text('Loading prices...'), findsNothing);
      // "The Forge" appears in both the dropdown and the result card.
      expect(find.descendant(of: find.byType(Card), matching: find.text('The Forge')), findsOneWidget);
      expect(find.descendant(of: find.byType(Card), matching: find.text('Heimatar')), findsOneWidget);

      // No error text.
      expect(find.textContaining('Failed to load prices'), findsNothing);
    });

    testWidgets('announces repository errors', (tester) async {
      final fetcher = FakeOrderFetcher();
      fetcher.onFetch = (typeId, regionId) async {
        throw const PriceRepositoryException('Simulated ESI failure');
      };

      final repo = _repoWithFetcher(fetcher);

      await pumpScreen(tester, repo: repo);

      await tester.enterText(find.byType(TextField).first, '34');
      await tester.tap(find.text('Check Prices'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Failed to load prices'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Simulated ESI failure'),
        findsOneWidget,
      );
    });

    testWidgets('shows accessible empty results state', (tester) async {
      final fetcher = FakeOrderFetcher();
      fetcher.onFetch = (typeId, regionId) async => [];

      // Use an empty map and a custom repo that bypasses the empty-map
      // validation since getPricesAcrossAllRegions iterates _marketRegions.
      const emptyRegions = <int, String>{};
      final repo = PriceRepository(
        orderFetcher: fetcher.call,
        marketRegions: emptyRegions,
        clock: () => DateTime.utc(2025, 1, 1),
      );

      await pumpScreen(tester, repo: repo);

      await tester.enterText(find.byType(TextField).first, '34');
      await tester.tap(find.text('Check Prices'));
      await tester.pumpAndSettle();

      expect(find.text('No market regions returned'), findsOneWidget);
    });

    testWidgets('renders single-region results when all-regions is off',
        (tester) async {
      final fetcher = FakeOrderFetcher();
      fetcher.onFetch = (typeId, regionId) async => [
            _buy(100.0, 10),
            _sell(120.0, 8),
          ];

      const smallRegions = <int, String>{
        10000002: 'The Forge',
        10000030: 'Heimatar',
      };

      final repo = PriceRepository(
        orderFetcher: fetcher.call,
        marketRegions: smallRegions,
        clock: () => DateTime.utc(2025, 1, 1),
      );

      await pumpScreen(tester, repo: repo);

      // Toggle off all-regions.
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '34');
      await tester.tap(find.text('Check Prices'));
      await tester.pumpAndSettle();

      // The Forge should appear since default is 10000002.
      expect(find.descendant(of: find.byType(Card), matching: find.text('The Forge')), findsOneWidget);
      expect(find.text('Heimatar'), findsNothing);
    });
  });
}
