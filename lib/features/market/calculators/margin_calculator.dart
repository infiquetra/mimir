/// Trade calculator for margin and profit calculations.
class TradeCalculator {
  /// Calculates the margin and profit for a trade.
  ///
  /// [buyPrice] is the price at which the item was bought.
  /// [sellPrice] is the price at which the item was sold.
  /// [brokerFeePercent] is the percentage fee charged by the broker (default: 1.0).
  /// [salesTaxPercent] is the percentage sales tax (default: 2.0).
  ///
  /// Returns a [TradeMargin] object containing all calculated values.
  ///
  /// Throws [ArgumentError] if any of the parameters are invalid.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    // Validate inputs
    if (buyPrice < 0) {
      throw ArgumentError('buyPrice must be non-negative, got $buyPrice');
    }
    if (sellPrice < 0) {
      throw ArgumentError('sellPrice must be non-negative, got $sellPrice');
    }
    if (brokerFeePercent < 0) {
      throw ArgumentError('brokerFeePercent must be non-negative, got $brokerFeePercent');
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError('salesTaxPercent must be non-negative, got $salesTaxPercent');
    }
    if (brokerFeePercent + salesTaxPercent >= 100) {
      throw ArgumentError(
          'Total fees and taxes must be less than 100%, got ${brokerFeePercent + salesTaxPercent}%');
    }

    // Calculate buy total (including broker fee)
    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);

    // Calculate sell net (after broker fee and sales tax)
    final sellNet = sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);

    // Calculate profit (sell net minus buy total)
    final profit = sellNet - buyTotal;

    // Calculate margin percentage (profit as percentage of buy total)
    final marginPercent = buyTotal > 0 ? (profit / buyTotal) * 100 : 0.0;

    // Calculate fees and taxes
    final brokerFee = buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100;
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

  /// Calculates the break-even sell price needed to achieve zero profit/loss.
  ///
  /// [buyPrice] is the price at which the item was bought.
  /// [brokerFeePercent] is the percentage fee charged by the broker (default: 1.0).
  /// [salesTaxPercent] is the percentage sales tax (default: 2.0).
  ///
  /// Returns the sell price needed to break even.
  ///
  /// Throws [ArgumentError] if any of the parameters are invalid.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    // Validate inputs
    if (buyPrice < 0) {
      throw ArgumentError('buyPrice must be non-negative, got $buyPrice');
    }
    if (brokerFeePercent < 0) {
      throw ArgumentError('brokerFeePercent must be non-negative, got $brokerFeePercent');
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError('salesTaxPercent must be non-negative, got $salesTaxPercent');
    }
    if (brokerFeePercent + salesTaxPercent >= 100) {
      throw ArgumentError(
          'Total fees and taxes must be less than 100%, got ${brokerFeePercent + salesTaxPercent}%');
    }

    // Calculate buy total (including broker fee)
    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);

    // Calculate net sell multiplier (1 - broker_fee_percent / 100 - sales_tax_percent / 100)
    final netSellMultiplier = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    // Return break-even sell price
    return buyTotal / netSellMultiplier;
  }
}

/// Result class for trade margin calculations.
class TradeMargin {
  /// The price at which the item was bought.
  final double buyPrice;

  /// The price at which the item was sold.
  final double sellPrice;

  /// The total buy price including broker fee.
  final double buyTotal;

  /// The net sell price after removing fees and taxes.
  final double sellNet;

  /// The absolute profit or loss from the trade.
  final double profit;

  /// The margin percentage as a percentage of the buy total.
  final double marginPercent;

  /// The total broker fee paid (calculated on both buy and sell prices).
  final double brokerFee;

  /// The sales tax paid on the sell price.
  final double salesTax;

  /// Whether the trade is profitable (profit > 0).
  bool get isProfitable => profit > 0;

  /// Creates a new [TradeMargin] instance.
  TradeMargin({
    required this.buyPrice,
    required this.sellPrice,
    required this.buyTotal,
    required this.sellNet,
    required this.profit,
    required this.marginPercent,
    required this.brokerFee,
    required this.salesTax,
  });
}