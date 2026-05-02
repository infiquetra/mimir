/// Immutable result of a trade margin calculation.
///
/// All fields are final; use [isProfitable] to check whether the trade
/// generates a positive profit.
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

  /// Returns `true` when the trade yields a strictly positive profit.
  bool get isProfitable => profit > 0;
}

/// Pure calculator for Eve Online trade margin and break-even analysis.
///
/// All methods are static; [TradeCalculator] cannot be instantiated.
class TradeCalculator {
  // Coverage: intentionally inaccessible — prevents accidental instantiation.
  const TradeCalculator._();

  /// Computes the margin for a trade given buy and sell prices plus
  /// applicable broker fee and sales tax percentages.
  ///
  /// The formulas are taken from the Market module blueprint
  /// (Price Calculations section).
  ///
  /// Throws [ArgumentError] if any argument is negative or if the
  /// combined sell-side fee percentages reach 100% or more.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateNonNegative('buyPrice', buyPrice);
    _validateNonNegative('sellPrice', sellPrice);
    _validateNonNegative('brokerFeePercent', brokerFeePercent);
    _validateNonNegative('salesTaxPercent', salesTaxPercent);
    _validateTotalSellFees(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
    final profit = sellNet - buyTotal;
    final marginPercent = buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;
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

  /// Returns the sell price at which the trade breaks even
  /// (profit == 0), given the buy price and fee percentages.
  ///
  /// Throws [ArgumentError] when any argument is negative or the
  /// combined fee percentages reach 100% or more (which would make
  /// the sell-side multiplier zero or negative).
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateNonNegative('buyPrice', buyPrice);
    _validateNonNegative('brokerFeePercent', brokerFeePercent);
    _validateNonNegative('salesTaxPercent', salesTaxPercent);
    _validateTotalSellFees(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellFeeMultiplier =
        1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    return buyTotal / sellFeeMultiplier;
  }

  static void _validateNonNegative(String name, double value) {
    if (value < 0) {
      throw ArgumentError.value(value, name, 'must be non-negative');
    }
  }

  static void _validateTotalSellFees(
    double brokerFeePercent,
    double salesTaxPercent,
  ) {
    final totalSellFeePercent = brokerFeePercent + salesTaxPercent;
    if (totalSellFeePercent >= 100) {
      throw ArgumentError.value(
        totalSellFeePercent,
        'brokerFeePercent + salesTaxPercent',
        'total sell fees must be less than 100%',
      );
    }
  }
}
