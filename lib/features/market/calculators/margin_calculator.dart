/// Margin and profit calculations for market trades.
///
/// Implements the Price Calculations section of the Market Module Specification.
class TradeCalculator {
  TradeCalculator._();

  /// Calculates margin and profit details for a trade.
  ///
  /// Takes a buy price, sell price, and fee percentages, then computes
  /// the total cost, net proceeds, profit/loss, and margin percent.
  ///
  /// Throws [ArgumentError] if any numeric value is negative or if
  /// combined sell-side fees are >= 100%.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    if (buyPrice < 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'must be non-negative',
      );
    }
    if (sellPrice < 0) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'must be non-negative',
      );
    }
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'must be non-negative',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'must be non-negative',
      );
    }
    final combinedFees = brokerFeePercent + salesTaxPercent;
    if (combinedFees >= 100) {
      throw ArgumentError(
        'combined sell-side fees must be less than 100%, got $combinedFees',
      );
    }

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
    final profit = sellNet - buyTotal;
    final marginPercent =
        buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;
    final brokerFee = buyPrice * brokerFeePercent / 100 +
        sellPrice * brokerFeePercent / 100;
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

  /// Calculates the break-even sell price for a given buy price and fees.
  ///
  /// The break-even price is the sell price at which profit is exactly zero.
  ///
  /// Throws [ArgumentError] if [buyPrice] is negative, if either fee percent
  /// is negative, or if combined sell-side fees are >= 100%.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    if (buyPrice < 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'must be non-negative',
      );
    }
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'must be non-negative',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'must be non-negative',
      );
    }
    final combinedFees = brokerFeePercent + salesTaxPercent;
    if (combinedFees >= 100) {
      throw ArgumentError(
        'combined sell-side fees must be less than 100%, got $combinedFees',
      );
    }

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNetMultiplier =
        1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    return buyTotal / sellNetMultiplier;
  }
}

/// Immutable record of margin calculation results.
class TradeMargin {
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

  /// Original buy price before fees.
  final double buyPrice;

  /// Original sell price before fees.
  final double sellPrice;

  /// Buy price plus buy-side broker fee.
  final double buyTotal;

  /// Sell price minus all sell-side fees.
  final double sellNet;

  /// Net profit or loss (sellNet minus buyTotal).
  final double profit;

  /// Profit as a percentage of buyTotal.
  final double marginPercent;

  /// Total broker fees (buy-side + sell-side).
  final double brokerFee;

  /// Sales tax amount (sell-side only).
  final double salesTax;

  /// Whether this trade generated a positive profit.
  bool get isProfitable => profit > 0;
}
