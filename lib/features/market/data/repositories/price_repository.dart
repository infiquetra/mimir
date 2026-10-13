import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Default region ID for single-region lookups (The Forge).
const defaultMarketRegionId = 10000002;

/// A single market order quote from ESI or a fake fetcher.
class MarketOrderQuote {
  final double price;
  final int volumeRemain;
  final bool isBuyOrder;

  const MarketOrderQuote({
    required this.price,
    required this.volumeRemain,
    required this.isBuyOrder,
  });
}

/// Aggregated market price data for a single type in a single region.
class MarketPrice {
  final int typeId;
  final String typeName;
  final double? buyMax;
  final double? sellMin;
  final double? buyAvg;
  final double? sellAvg;
  final int buyVolume;
  final int sellVolume;
  final int regionId;
  final DateTime updatedAt;

  const MarketPrice({
    required this.typeId,
    required this.typeName,
    this.buyMax,
    this.sellMin,
    this.buyAvg,
    this.sellAvg,
    this.buyVolume = 0,
    this.sellVolume = 0,
    required this.regionId,
    required this.updatedAt,
  });

  /// The absolute spread: sellMin - buyMax. Returns `null` if either
  /// side is unavailable.
  double? get spread =>
      (buyMax != null && sellMin != null) ? sellMin! - buyMax! : null;

  /// Spread as a percentage of buyMax. Returns `null` if spread cannot
  /// be computed or buyMax is 0.
  double? get spreadPercent {
    final s = spread;
    if (s == null || buyMax == null || buyMax == 0) return null;
    return (s / buyMax!) * 100;
  }

  /// Margin: sellMin * 0.99 - buyMax * 1.01 (broker-fee approximation).
  /// Returns `null` if either side is unavailable.
  double? get margin {
    if (buyMax == null || sellMin == null) return null;
    return sellMin! * 0.99 - buyMax! * 1.01;
  }
}

/// A price result for a single region, used by all-regions queries.
class MarketRegionPrice {
  final int regionId;
  final String regionName;
  final MarketPrice price;

  const MarketRegionPrice({
    required this.regionId,
    required this.regionName,
    required this.price,
  });
}

/// Exception raised when price operations fail.
class PriceRepositoryException implements Exception {
  final String message;

  const PriceRepositoryException(this.message);

  @override
  String toString() => 'PriceRepositoryException: $message';
}

/// Signature for a function that fetches market order quotes for a given
/// type in a given region.
typedef MarketOrderFetcher = Future<List<MarketOrderQuote>> Function(
  int typeId,
  int regionId,
);

/// The authoritative catalog of known-space EVE market regions.
///
/// Excludes non-market / Jove / pseudo regions:
///   10000004 (UUA-F4), 10000017 (J174102), 10000019 (A821-A),
///   10000024 (J200727), 10000026 (AD0006).
const Map<int, String> eveMarketRegions = <int, String>{
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
};

/// Repository for fetching and aggregating EVE market price data.
///
/// Supports single-region and all-regions price lookups with injectable
/// order fetching for testability.
class PriceRepository {
  final Dio _dio;
  final MarketOrderFetcher? _orderFetcher;
  final Map<int, String> _marketRegions;
  final DateTime Function() _clock;

  PriceRepository({
    Dio? dio,
    MarketOrderFetcher? orderFetcher,
    Map<int, String>? marketRegions,
    DateTime Function()? clock,
  })  : _dio = dio ?? Dio(BaseOptions(baseUrl: 'https://esi.evetech.net/latest')),
        _orderFetcher = orderFetcher,
        _marketRegions = marketRegions ?? eveMarketRegions,
        _clock = clock ?? (() => DateTime.now());

  /// Returns the configured market-region catalog.
  Map<int, String> get marketRegions => Map.unmodifiable(_marketRegions);

  /// The Dio instance used for ESI calls (exposed for testing).
  Dio get dio => _dio;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Fetches and aggregates market prices for a single type in a single
  /// region.
  Future<MarketPrice> getPrice(
    int typeId,
    int regionId, {
    String? typeName,
  }) async {
    if (typeId <= 0) {
      throw ArgumentError.value(
        typeId,
        'typeId',
        'expected positive EVE type id',
      );
    }
    if (!_marketRegions.containsKey(regionId)) {
      throw ArgumentError.value(
        regionId,
        'regionId',
        'expected known market region id',
      );
    }

    final orders = await (_orderFetcher?.call(typeId, regionId) ??
        _fetchWithDio(typeId, regionId));
    return _aggregate(orders, typeId, regionId, typeName);
  }

  /// Fetches and aggregates market prices for a single type across every
  /// configured region.
  ///
  /// Returns one [MarketRegionPrice] per region in [marketRegions]
  /// insertion order. Throws [PriceRepositoryException] if any region
  /// fetch fails — partial results are never returned.
  Future<List<MarketRegionPrice>> getPricesAcrossAllRegions(
    int typeId, {
    String? typeName,
  }) async {
    if (typeId <= 0) {
      throw ArgumentError.value(
        typeId,
        'typeId',
        'expected positive EVE type id',
      );
    }

    final results = <MarketRegionPrice>[];
    for (final entry in _marketRegions.entries) {
      try {
        final price = await getPrice(typeId, entry.key, typeName: typeName);
        results.add(MarketRegionPrice(
          regionId: entry.key,
          regionName: entry.value,
          price: price,
        ));
      } catch (e) {
        throw PriceRepositoryException(
          'Failed to fetch prices for region ${entry.key} (${entry.value}): $e',
        );
      }
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  MarketPrice _aggregate(
    List<MarketOrderQuote> orders,
    int typeId,
    int regionId,
    String? typeName,
  ) {
    final buys = orders.where((o) => o.isBuyOrder).toList();
    final sells = orders.where((o) => !o.isBuyOrder).toList();

    final buyMax = buys.isEmpty
        ? null
        : buys.map((o) => o.price).reduce((a, b) => a > b ? a : b);
    final sellMin = sells.isEmpty
        ? null
        : sells.map((o) => o.price).reduce((a, b) => a < b ? a : b);
    final buyAvg = buys.isEmpty
        ? null
        : buys.map((o) => o.price).reduce((a, b) => a + b) / buys.length;
    final sellAvg = sells.isEmpty
        ? null
        : sells.map((o) => o.price).reduce((a, b) => a + b) / sells.length;
    final buyVolume = buys.fold<int>(0, (sum, o) => sum + o.volumeRemain);
    final sellVolume = sells.fold<int>(0, (sum, o) => sum + o.volumeRemain);

    return MarketPrice(
      typeId: typeId,
      typeName: typeName ?? 'Type $typeId',
      buyMax: buyMax,
      sellMin: sellMin,
      buyAvg: buyAvg,
      sellAvg: sellAvg,
      buyVolume: buyVolume,
      sellVolume: sellVolume,
      regionId: regionId,
      updatedAt: _clock(),
    );
  }

  // ---------------------------------------------------------------------------
  // Default ESI fetcher
  // ---------------------------------------------------------------------------

  /// The default ESI order fetching path. Uses [dio] to request every page
  /// of `/markets/{region_id}/orders/` with `type_id`, `order_type=all`,
  /// and `datasource=tranquility`.
  ///
  /// Exposed as a public method so tests can verify pagination via a fake
  /// Dio adapter injected into the [dio] field.
  Future<List<MarketOrderQuote>> _fetchWithDio(
    int typeId,
    int regionId,
  ) async {
    return _fetchAllPages(_dio, typeId, regionId);
  }

  static Future<List<MarketOrderQuote>> _fetchAllPages(
    Dio dio,
    int typeId,
    int regionId,
  ) async {
    final allOrders = <MarketOrderQuote>[];
    int totalPages = 1;

    // Page 1 — also reads X-Pages header.
    final page1Response = await _fetchSinglePage(dio, typeId, regionId, 1);
    final headerValue = page1Response.headers.value('x-pages');
    if (headerValue != null) {
      final parsed = int.tryParse(headerValue);
      if (parsed == null || parsed <= 0) {
        throw PriceRepositoryException(
          'Invalid X-Pages header for typeId=$typeId regionId=$regionId '
          'page=1: "$headerValue"',
        );
      }
      totalPages = parsed;
    }

    allOrders.addAll(page1Response.data as List<MarketOrderQuote>);

    // Remaining pages 2..totalPages.
    for (int page = 2; page <= totalPages; page++) {
      final response = await _fetchSinglePage(dio, typeId, regionId, page);
      allOrders.addAll(response.data as List<MarketOrderQuote>);
    }

    return allOrders;
  }

  static Future<Response<List<MarketOrderQuote>>> _fetchSinglePage(
    Dio dio,
    int typeId,
    int regionId,
    int page,
  ) async {
    try {
      final response = await dio.get(
        '/markets/$regionId/orders/',
        queryParameters: {
          'type_id': typeId,
          'order_type': 'all',
          'datasource': 'tranquility',
          'page': page,
        },
      );

      final body = response.data;
      if (body is! List) {
        throw PriceRepositoryException(
          'Expected JSON array from /markets/$regionId/orders/ page=$page, '
          'got ${body.runtimeType}',
        );
      }

      final orders = <MarketOrderQuote>[];
      for (int i = 0; i < body.length; i++) {
        final item = body[i];
        if (item is! Map<String, dynamic>) {
          throw PriceRepositoryException(
            'Invalid order entry at index $i page=$page region=$regionId: '
            'expected Map, got ${item.runtimeType}',
          );
        }
        final price = item['price'];
        final volumeRemain = item['volume_remain'];
        final isBuyOrder = item['is_buy_order'];

        if (price is! num) {
          throw PriceRepositoryException(
            'Missing or invalid "price" at index $i page=$page '
            'region=$regionId: got ${price.runtimeType}',
          );
        }
        if (volumeRemain is! int) {
          throw PriceRepositoryException(
            'Missing or invalid "volume_remain" at index $i page=$page '
            'region=$regionId: got ${volumeRemain.runtimeType}',
          );
        }
        if (isBuyOrder is! bool) {
          throw PriceRepositoryException(
            'Missing or invalid "is_buy_order" at index $i page=$page '
            'region=$regionId: got ${isBuyOrder.runtimeType}',
          );
        }

        orders.add(MarketOrderQuote(
          price: price.toDouble(),
          volumeRemain: volumeRemain,
          isBuyOrder: isBuyOrder,
        ));
      }

      return Response(
        data: orders,
        statusCode: response.statusCode,
        requestOptions: response.requestOptions,
        headers: response.headers,
      );
    } on PriceRepositoryException {
      rethrow;
    } catch (e) {
      throw PriceRepositoryException(
        'Failed to fetch /markets/$regionId/orders/ page=$page for '
        'typeId=$typeId: $e',
      );
    }
  }
}

/// Riverpod provider for [PriceRepository].
final priceRepositoryProvider = Provider<PriceRepository>(
  (ref) => PriceRepository(),
);
