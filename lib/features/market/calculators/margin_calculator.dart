/// Trade margin calculator for the Market module.
/// Implements the Price Calculations section of the market specification.
class TradeCalculator {
  TradeCalculator._();

  /// Calculates the full margin breakdown for a trade.
  ///
  /// [buyPrice] - the purchase price before buy-side fees
  /// [sellPrice] - the sale price before sell-side fees
  /// [brokerFeePercent] - buy-side broker fee percentage (default 1.0%)
  /// [salesTaxPercent] - sell-side sales tax percentage (default 2.0%)
  ///
  /// Throws [ArgumentError] for negative prices/fees or if combined
  /// sell-side fees are >= 100%.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    // Validate inputs
    if (buyPrice < 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'buyPrice must not be negative',
      );
    }
    if (sellPrice < 0) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'sellPrice must not be negative',
      );
    }
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'brokerFeePercent must not be negative',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'salesTaxPercent must not be negative',
      );
    }
    final combinedSellFees = brokerFeePercent + salesTaxPercent;
    if (combinedSellFees >= 100) {
      throw ArgumentError(
        'Combined sell-side fees must be less than 100%. '
        'Got brokerFeePercent=$brokerFeePercent + salesTaxPercent=$salesTaxPercent = $combinedSellFees%',
      );
    }

    // Buy-side: total cost including broker fee
    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);

    // Sell-side: net proceeds after broker fee and sales tax
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);

    // Profit and margin
    final profit = sellNet - buyTotal;
    final marginPercent = buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;

    // Fee breakdown
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

  /// Calculates the break-even sell price for a given buy price and fees.
  ///
  /// [buyPrice] - the purchase price before buy-side fees
  /// [brokerFeePercent] - buy-side broker fee percentage (default 1.0%)
  /// [salesTaxPercent] - sell-side sales tax percentage (default 2.0%)
  ///
  /// Throws [ArgumentError] for negative values or if combined
  /// sell-side fees are >= 100%.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    // Validate inputs
    if (buyPrice < 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'buyPrice must not be negative',
      );
    }
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'brokerFeePercent must not be negative',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'salesTaxPercent must not be negative',
      );
    }
    final combinedSellFees = brokerFeePercent + salesTaxPercent;
    if (combinedSellFees >= 100) {
      throw ArgumentError(
        'Combined sell-side fees must be less than 100%. '
        'Got brokerFeePercent=$brokerFeePercent + salesTaxPercent=$salesTaxPercent = $combinedSellFees%',
      );
    }

    // Buy-side: total cost including broker fee
    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);

    // Sell-net multiplier (what portion of sell price remains after fees)
    final sellNetMultiplier = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    // Break-even: sell price where sellNet == buyTotal
    return buyTotal / sellNetMultiplier;
  }
}

/// Immutable result of a margin calculation.
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

  /// Total cost including buy-side broker fee.
  final double buyTotal;

  /// Net proceeds after sell-side broker fee and sales tax.
  final double sellNet;

  /// Profit (or loss) from the trade.
  final double profit;

  /// Profit as a percentage of buy total.
  final double marginPercent;

  /// Total broker fees (buy-side + sell-side).
  final double brokerFee;

  /// Sales tax on the sell side.
  final double salesTax;

  /// True if this trade is profitable (profit > 0).
  bool get isProfitable => profit > 0;
}
