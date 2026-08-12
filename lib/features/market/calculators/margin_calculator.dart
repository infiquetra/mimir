/// Immutable result of a margin calculation.
///
/// All amounts are in ISK. [marginPercent] is the profit as a percentage
/// of the total buy cost. [isProfitable] is true when [profit] > 0.
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

  bool get isProfitable => profit > 0;

  @override
  String toString() =>
      'TradeMargin(buyPrice: $buyPrice, sellPrice: $sellPrice, '
      'buyTotal: $buyTotal, sellNet: $sellNet, profit: $profit, '
      'marginPercent: $marginPercent, brokerFee: $brokerFee, '
      'salesTax: $salesTax, isProfitable: $isProfitable)';
}

/// Static utility for station-trade margin and break-even calculations.
///
/// All monetary values are in ISK; percentages are in the range [0, 100).
/// The combined broker fee and sales tax percentages must be less than 100
/// or the sell-side net would be zero (or negative), making the calculation
/// meaningless.
class TradeCalculator {
  const TradeCalculator._();

  // -----------------------------------------------------------------------
  // Validation helpers
  // -----------------------------------------------------------------------

  static void _validatePrice(String name, double value,
      {bool allowZero = true}) {
    if (!value.isFinite || value < 0 || (value == 0 && !allowZero)) {
      throw ArgumentError.value(
        value,
        name,
        'Expected a finite ${allowZero ? 'non-negative' : 'positive'} ISK value',
      );
    }
  }

  static void _validatePercent(String name, double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'Expected a finite non-negative percent',
      );
    }
  }

  static void _validateSellDeductions(
      double brokerFeePercent, double salesTaxPercent) {
    if (1 - brokerFeePercent / 100 - salesTaxPercent / 100 <= 0) {
      throw ArgumentError(
        'Expected brokerFeePercent + salesTaxPercent to be less than 100, '
        'got brokerFeePercent=$brokerFeePercent, '
        'salesTaxPercent=$salesTaxPercent',
      );
    }
  }

  // -----------------------------------------------------------------------
  // Margin calculation
  // -----------------------------------------------------------------------

  /// Calculates the trade margin for a station trade.
  ///
  /// [buyPrice] must be positive. [sellPrice] may be zero (e.g. for break-
  /// even analysis that only computes buy side). Both percentage parameters
  /// default to mimir-blueprint baseline values (1 % broker, 2 % sales tax).
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePrice('buyPrice', buyPrice, allowZero: false);
    _validatePrice('sellPrice', sellPrice);
    _validatePercent('brokerFeePercent', brokerFeePercent);
    _validatePercent('salesTaxPercent', salesTaxPercent);
    _validateSellDeductions(brokerFeePercent, salesTaxPercent);

    final buyBrokerFee = buyPrice * brokerFeePercent / 100;
    final sellBrokerFee = sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    final buyTotal = buyPrice + buyBrokerFee;
    final sellNet = sellPrice - sellBrokerFee - salesTax;
    final profit = sellNet - buyTotal;
    final marginPercent = (profit / buyTotal) * 100;
    final brokerFee = buyBrokerFee + sellBrokerFee;

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

  // -----------------------------------------------------------------------
  // Break-even sell price
  // -----------------------------------------------------------------------

  /// The minimum sell price at which the trade breaks even.
  ///
  /// This covers the buy price, broker fees on both sides, and sales tax.
  /// Both percentage parameters default to mimir-blueprint baseline values.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePrice('buyPrice', buyPrice, allowZero: false);
    _validatePercent('brokerFeePercent', brokerFeePercent);
    _validatePercent('salesTaxPercent', salesTaxPercent);
    _validateSellDeductions(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellRetentionRate =
        1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    return buyTotal / sellRetentionRate;
  }
}
