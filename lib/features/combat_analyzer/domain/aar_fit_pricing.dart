import '../../../core/utils/formatters.dart';
import 'aar_fit_bom.dart';

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

/// Exact decimal ISK amount as [coefficient] × 10^-[scale].
///
/// Multiply by integer quantity in this representation; round only at
/// [formatIsk] presentation.
class IskEstimateAmount {
  const IskEstimateAmount({required this.coefficient, this.scale = 0});

  final int coefficient;
  final int scale;

  factory IskEstimateAmount.fromAverage(double average) {
    if (!average.isFinite || average < 0) {
      throw ArgumentError.value(
        average,
        'average',
        'must be nonnegative and finite',
      );
    }
    if (average == 0) {
      return const IskEstimateAmount(coefficient: 0);
    }
    final text = average.toString();
    if (text.contains('e') || text.contains('E')) {
      return _fromScaledDouble(average);
    }
    final unsigned = text.startsWith('-') ? text.substring(1) : text;
    final parts = unsigned.split('.');
    final whole = parts[0];
    var frac = parts.length > 1 ? parts[1] : '';
    frac = frac.replaceFirst(RegExp(r'0+$'), '');
    final parsedScale = frac.length;
    final digits = parsedScale == 0 ? whole : '$whole$frac';
    return IskEstimateAmount(
      coefficient: int.parse(digits),
      scale: parsedScale,
    );
  }

  static IskEstimateAmount _fromScaledDouble(double average) {
    var scale = 0;
    var value = average;
    while (scale < 15) {
      final nearest = value.round();
      if ((value - nearest).abs() < 1e-9) {
        return IskEstimateAmount(coefficient: nearest, scale: scale);
      }
      value *= 10;
      scale += 1;
    }
    return IskEstimateAmount(coefficient: value.round(), scale: scale);
  }

  IskEstimateAmount times(int quantity) {
    if (quantity < 0) {
      throw ArgumentError.value(quantity, 'quantity', 'must be non-negative');
    }
    return IskEstimateAmount(coefficient: coefficient * quantity, scale: scale);
  }

  IskEstimateAmount plus(IskEstimateAmount other) {
    if (scale == other.scale) {
      return IskEstimateAmount(
        coefficient: coefficient + other.coefficient,
        scale: scale,
      );
    }
    final aligned = scale > other.scale ? scale : other.scale;
    return IskEstimateAmount(
      coefficient:
          coefficient * _pow10(aligned - scale) +
          other.coefficient * _pow10(aligned - other.scale),
      scale: aligned,
    );
  }

  double get asDouble => coefficient / _pow10(scale);

  String format() => formatIsk(asDouble);

  static int _pow10(int exponent) {
    var n = 1;
    for (var i = 0; i < exponent; i++) {
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
    this.sourceLabel = _esiAverageLabel,
    this.unavailableReason,
  });

  static const _esiAverageLabel = 'ESI average price estimate';
  static const _staleAfter = Duration(hours: 24);

  final int typeId;
  final IskEstimateAmount? unitPrice;
  final DateTime? lastUpdated;
  final bool isStale;
  final bool uncertain;
  final String sourceLabel;
  final String? unavailableReason;

  bool get isPriced => unitPrice != null && unavailableReason == null;

  /// Average price only. Adjusted price and Dogma cost are never purchase
  /// prices. Exact 24h age is stale; future-dated quotes are uncertain.
  factory AarPriceEstimate.fromQuote(
    AarMarketQuote quote, {
    required DateTime now,
  }) {
    final average = quote.averagePrice;
    final futureDated =
        quote.lastUpdated != null && quote.lastUpdated!.isAfter(now);
    final stale =
        !futureDated &&
        quote.lastUpdated != null &&
        now.difference(quote.lastUpdated!) >= _staleAfter;

    if (average == null || !average.isFinite || average < 0) {
      return AarPriceEstimate(
        typeId: quote.typeId,
        lastUpdated: quote.lastUpdated,
        isStale: stale,
        uncertain: futureDated,
        sourceLabel: _esiAverageLabel,
        unavailableReason: _unavailableReason(quote, average),
      );
    }

    return AarPriceEstimate(
      typeId: quote.typeId,
      unitPrice: IskEstimateAmount.fromAverage(average),
      lastUpdated: quote.lastUpdated,
      isStale: stale,
      uncertain: futureDated,
      sourceLabel: _esiAverageLabel,
    );
  }

  static String _unavailableReason(AarMarketQuote quote, double? average) {
    if (average != null && (!average.isFinite || average < 0)) {
      return 'invalid';
    }
    if (quote.adjustedPrice != null || quote.dogmaCost != 0) {
      return 'adjusted_only';
    }
    return 'unavailable';
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

  /// Gross priced-line sum. Unpriced and unknown-quantity lines stay in
  /// [AarPricedSubtotal.lines] but never enter the subtotal or a "total cost".
  AarPricedSubtotal price({
    required FitBillOfMaterials bom,
    required List<AarPriceEstimate> estimates,
  }) {
    final byType = <int, AarPriceEstimate>{
      for (final estimate in estimates) estimate.typeId: estimate,
    };
    final lines = <AarPricedLine>[];
    var amount = const IskEstimateAmount(coefficient: 0);
    var priced = 0;
    var known = 0;

    for (final requirement in bom.requirements) {
      final quantity = requirement.requiredCount;
      if (quantity != null && quantity <= 0 && !requirement.quantityUnknown) {
        continue;
      }
      known += 1;
      final estimate = byType[requirement.typeId];
      final countable =
          quantity != null && quantity > 0 && !requirement.quantityUnknown;
      final pricedLine = countable && estimate != null && estimate.isPriced;
      IskEstimateAmount? extension;
      if (pricedLine) {
        extension = estimate.unitPrice!.times(quantity);
        amount = amount.plus(extension);
        priced += 1;
      }
      lines.add(
        AarPricedLine(
          typeId: requirement.typeId,
          quantity: quantity ?? 0,
          estimate: estimate,
          extension: extension,
          label: _lineLabel(estimate: estimate, priced: pricedLine),
        ),
      );
    }

    return AarPricedSubtotal(
      heading: 'Priced subtotal',
      amount: amount,
      pricedLines: priced,
      knownLines: known,
      lines: lines,
    );
  }

  static String _lineLabel({
    required AarPriceEstimate? estimate,
    required bool priced,
  }) {
    if (!priced) return 'Price unavailable';
    if (estimate!.unitPrice!.asDouble == 0) return '0 ISK estimate';
    return estimate.unitPrice!.format();
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

  /// Price-only refresh. Order and asset sync are never invoked. Failure
  /// retains the previous cached estimates.
  Future<void> refresh() async {
    priceSyncs += 1;
    cached = await syncPrices();
  }
}
