import '../../../core/utils/formatters.dart';
import 'aar_fit_bom.dart';

/// Compile stub for W5. GREEN uses averagePrice only, coefficient/scale
/// arithmetic, inclusive 24h stale, and priced-subtotal coverage.
class AarMarketQuote {
  const AarMarketQuote({
    required this.typeId,
    this.averagePrice,
    this.adjustedPrice,
    this.dogmaCost = 0,
    this.lastUpdated,
  });

  final int typeId;
  final double? averagePrice;
  final double? adjustedPrice;
  final double dogmaCost;
  final DateTime? lastUpdated;
}

class IskEstimateAmount {
  const IskEstimateAmount({required this.coefficient, this.scale = 0});

  final int coefficient;
  final int scale;

  /// Naive: stores a rounded double instead of exact decimal scale.
  factory IskEstimateAmount.fromAverage(double average) {
    return IskEstimateAmount(coefficient: (average * 100).round(), scale: 2);
  }

  /// Naive: rounds after converting through double.
  IskEstimateAmount times(int quantity) {
    final value = (coefficient / _pow10(scale)) * quantity;
    return IskEstimateAmount(coefficient: (value * 100).round(), scale: 2);
  }

  double get asDouble => coefficient / _pow10(scale);

  String format() => formatIsk(asDouble);

  static int _pow10(int scale) {
    var n = 1;
    for (var i = 0; i < scale; i++) {
      n *= 10;
    }
    return n;
  }
}

class AarPriceEstimate {
  const AarPriceEstimate({
    required this.typeId,
    this.unitPrice,
    this.lastUpdated,
    this.isStale = false,
    this.uncertain = false,
    this.sourceLabel = 'market',
    this.unavailableReason,
  });

  final int typeId;
  final IskEstimateAmount? unitPrice;
  final DateTime? lastUpdated;
  final bool isStale;
  final bool uncertain;
  final String sourceLabel;
  final String? unavailableReason;

  bool get isPriced => unitPrice != null && unavailableReason == null;

  /// Naive: falls back to adjustedPrice/Dogma cost; exact 24h is fresh;
  /// future-dated quotes are treated as fresh.
  factory AarPriceEstimate.fromQuote(
    AarMarketQuote quote, {
    required DateTime now,
  }) {
    final unit = quote.averagePrice ?? quote.adjustedPrice ?? quote.dogmaCost;
    final hasUnit = unit > 0;
    final age = quote.lastUpdated == null
        ? null
        : now.difference(quote.lastUpdated!);
    return AarPriceEstimate(
      typeId: quote.typeId,
      unitPrice: hasUnit ? IskEstimateAmount.fromAverage(unit) : null,
      lastUpdated: quote.lastUpdated,
      isStale: age != null && age > const Duration(hours: 24),
      uncertain: false,
      sourceLabel: 'market',
      unavailableReason: hasUnit ? null : 'missing',
    );
  }
}

class AarPricedLine {
  const AarPricedLine({
    required this.typeId,
    required this.quantity,
    this.estimate,
    this.extension,
    this.label,
  });

  final int typeId;
  final int quantity;
  final AarPriceEstimate? estimate;
  final IskEstimateAmount? extension;
  final String? label;
}

class AarPricedSubtotal {
  const AarPricedSubtotal({
    required this.heading,
    required this.amount,
    required this.pricedLines,
    required this.knownLines,
    this.lines = const [],
  });

  final String heading;
  final IskEstimateAmount amount;
  final int pricedLines;
  final int knownLines;
  final List<AarPricedLine> lines;

  String get coverage => '$pricedLines/$knownLines';
}

class AarBomPricer {
  const AarBomPricer();

  /// Naive: prices missing lines at 0, uses every estimate including
  /// adjusted fallbacks, and labels the sum Total cost.
  AarPricedSubtotal price({
    required FitBillOfMaterials bom,
    required List<AarPriceEstimate> estimates,
  }) {
    final byType = {
      for (final estimate in estimates) estimate.typeId: estimate,
    };
    final lines = <AarPricedLine>[];
    var coefficient = 0;
    var priced = 0;
    for (final requirement in bom.requirements) {
      final quantity = requirement.requiredCount ?? 0;
      if (quantity <= 0 && !requirement.quantityUnknown) continue;
      final estimate = byType[requirement.typeId];
      final extension = estimate?.unitPrice?.times(quantity);
      if (estimate?.isPriced == true) priced += 1;
      coefficient += extension?.coefficient ?? 0;
      lines.add(
        AarPricedLine(
          typeId: requirement.typeId,
          quantity: quantity,
          estimate: estimate,
          extension: extension,
          label: estimate?.isPriced == true ? null : 'free',
        ),
      );
    }
    return AarPricedSubtotal(
      heading: 'Total cost',
      amount: IskEstimateAmount(coefficient: coefficient, scale: 2),
      pricedLines: priced,
      knownLines: bom.requirements.length,
      lines: lines,
    );
  }
}

class AarPriceRefreshController {
  AarPriceRefreshController({
    required this.syncPrices,
    this.syncOrders,
    this.syncAssets,
    List<AarPriceEstimate>? cached,
  }) : cached = List<AarPriceEstimate>.from(cached ?? const []);

  final Future<List<AarPriceEstimate>> Function() syncPrices;
  final Future<void> Function()? syncOrders;
  final Future<void> Function()? syncAssets;
  List<AarPriceEstimate> cached;
  int priceSyncs = 0;
  int orderSyncs = 0;
  int assetSyncs = 0;

  /// Naive: also syncs orders and assets; failure clears the cache.
  Future<void> refresh() async {
    try {
      await syncAssets?.call();
      assetSyncs += 1;
      await syncOrders?.call();
      orderSyncs += 1;
      priceSyncs += 1;
      cached = await syncPrices();
    } catch (_) {
      cached = [];
      rethrow;
    }
  }
}
