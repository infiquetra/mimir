/// Immutable result of a margin calculation.
///
/// All fields are [double] and the constructor is [const] so callers
/// receive a stable snapshot of the computed values.
class TradeMargin {
  final double buyPrice;
  final double sellPrice;
  final double buyTotal;
  final double sellNet;
  final double profit;
  final double marginPercent;
  final double brokerFee;
  final double salesTax;

  const TradeMargin({
    required this.buyPrice,
    required this.sellPrice,
    required this.buyTotal,
    required this.sellNet,
    required this.profit,
    required this.marginPercent,
    required this.brokerFee,
    required this.salesTax,
  });

  /// A trade is only profitable when profit is strictly positive.
  /// Zero-profit and loss trades return `false`.
  bool get isProfitable => profit > 0;
}

/// Pure-Dart calculator for EVE Online trading margin and break-even
/// analysis.
///
/// All methods are static and have zero runtime or framework
/// dependencies; they only use the Dart core library.
class MarginCalculator {
  /// Validates fee percentage inputs common to [calculateMargin] and
  /// [breakEvenSellPrice].
  ///
  /// Throws [ArgumentError] if any constraint is violated.
  static void _validateFeeParams({
    required double buyPrice,
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    if (buyPrice.isNaN || buyPrice.isInfinite) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'must be a finite number',
      );
    }
    if (buyPrice <= 0) {
      throw ArgumentError.value(buyPrice, 'buyPrice', 'must be positive');
    }
    if (brokerFeePercent.isNaN || brokerFeePercent.isInfinite) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'must be a finite number',
      );
    }
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'must not be negative',
      );
    }
    if (salesTaxPercent.isNaN || salesTaxPercent.isInfinite) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'must be a finite number',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'must not be negative',
      );
    }
    if (brokerFeePercent + salesTaxPercent >= 100) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'brokerFeePercent ($brokerFeePercent) + salesTaxPercent '
            '($salesTaxPercent) must be less than 100',
      );
    }
  }

  /// Computes full margin details for a station-trading round-trip.
  ///
  /// [buyPrice] and [sellPrice] are the raw ISK amounts before fees.
  /// [brokerFeePercent] and [salesTaxPercent] default to the typical
  /// EVE Online NPC rates (1 % broker fee, 2 % sales tax) and scale
  /// as percentages (e.g. pass `1.0` for 1 %).
  ///
  /// Throws [ArgumentError] when inputs are out of the allowed
  /// range (negative fees, non-positive buy price, or combined
  /// sell-side fees ≥ 100 %).
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateFeeParams(
      buyPrice: buyPrice,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

    if (sellPrice.isNaN || sellPrice.isInfinite) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'must be a finite number',
      );
    }
    if (sellPrice < 0) {
      throw ArgumentError.value(sellPrice, 'sellPrice', 'must not be negative');
    }

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
    final profit = sellNet - buyTotal;
    final marginPercent = (profit / buyTotal) * 100;
    final brokerFee =
        buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    return TradeMargin(
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      buyTotal: buyTotal,
      sellNet: sellNet,
      profit: profit,
      marginPercent: marginPercent,
      brokerFee: brokerFee,
      salesTax: salesTax,
    );
  }

  /// Returns the minimum sell price (ISK) required to break even
  /// after broker fees and sales tax.
  ///
  /// [buyPrice] is the raw ISK purchase amount.
  /// [brokerFeePercent] and [salesTaxPercent] work exactly as in
  /// [calculateMargin].
  ///
  /// Throws [ArgumentError] when buy price is non-positive or fees
  /// are invalid.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateFeeParams(
      buyPrice: buyPrice,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellFeeMultiplier =
        1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    return buyTotal / sellFeeMultiplier;
  }
}
