/// Immutable result object returned by [TradeCalculator.calculateMargin].
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

  /// Returns `true` when the trade yields a positive profit.
  bool get isProfitable => profit > 0;
}

/// Static utility for EVE Online station trading calculations.
///
/// All methods are dependency-free pure functions — deterministic and side-effect free.
class TradeCalculator {
  TradeCalculator._(); // static utility, no instantiation

  /// Computes the margin for a station trade.
  ///
  /// Defaults match the EVE Online station trading baseline:
  /// - [brokerFeePercent] = 1.0 (Broker Relations V)
  /// - [salesTaxPercent] = 2.0 (Accounting V)
  ///
  /// Throws [ArgumentError] if any price is zero or negative, any fee is negative, or if the combined
  /// sell-side fee rates reach or exceed 100%.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateInputs(
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

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

  /// Returns the minimum sell price required to break even.
  ///
  /// Throws [ArgumentError] if [buyPrice] or a fee is negative, or if the
  /// combined sell-side fee rates reach or exceed 100%.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateInputs(
      buyPrice: buyPrice,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final feeMultiplier = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    return buyTotal / feeMultiplier;
  }

  // ---- private validation ------------------------------------------------

  static void _validateInputs({
    double? buyPrice,
    double? sellPrice,
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    if (buyPrice != null && buyPrice <= 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'buyPrice must be > 0',
      );
    }
    if (sellPrice != null && sellPrice <= 0) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'sellPrice must be > 0',
      );
    }
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'brokerFeePercent must be >= 0',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'salesTaxPercent must be >= 0',
      );
    }
    if (brokerFeePercent + salesTaxPercent >= 100) {
      throw ArgumentError.value(
        brokerFeePercent + salesTaxPercent,
        'brokerFeePercent + salesTaxPercent',
        'brokerFeePercent + salesTaxPercent must be < 100',
      );
    }
  }
}
