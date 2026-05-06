/// Market module margin and profit calculations.
///
/// Implements the margin calculator capability from the market blueprint
/// `## Price Calculations` section. Provides [TradeCalculator] with static
/// methods for margin analysis and break-even pricing, plus [TradeMargin]
/// as a value object holding calculated results.
library;

/// Pure calculator for trade margin and break-even analysis.
///
/// All methods are static. The class is not meant to be instantiated —
/// use the private constructor to prevent construction.
class TradeCalculator {
  // Private constructor prevents instantiation of this static utility class.
  // ignore: unused_element
  TradeCalculator._();

  /// Calculates the margin for a potential trade.
  ///
  /// Returns a [TradeMargin] with all computed values. Both buy and sell
  /// sides incur the broker fee; only the sell side incurs sales tax.
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

    final buyBrokerFee = buyPrice * brokerFeePercent / 100;
    final sellBrokerFee = sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    final buyTotal = buyPrice + buyBrokerFee;
    final sellNet = sellPrice - sellBrokerFee - salesTax;
    final profit = sellNet - buyTotal;
    final marginPercent = buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;
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

  /// Computes the minimum sell price needed to break even.
  ///
  /// Accounts for broker fees on both buy and sell sides plus sales tax
  /// on the sell side. Returns the sell price at which profit = 0.
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
    final sellRetentionRate =
        1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    return buyTotal / sellRetentionRate;
  }

  /// Validates all numeric inputs before calculation.
  ///
  /// Throws [ArgumentError] with context naming the invalid field
  /// if any value is non-finite, negative where forbidden, or if
  /// combined sell-side deductions reach 100% or more.
  static void _validateInputs({
    required double buyPrice,
    double? sellPrice,
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    if (!buyPrice.isFinite || buyPrice < 0) {
      throw ArgumentError(
        'buyPrice must be finite and non-negative, got $buyPrice',
      );
    }
    if (sellPrice != null && (!sellPrice.isFinite || sellPrice < 0)) {
      throw ArgumentError(
        'sellPrice must be finite and non-negative, got $sellPrice',
      );
    }
    if (!brokerFeePercent.isFinite || brokerFeePercent < 0) {
      throw ArgumentError(
        'brokerFeePercent must be finite and non-negative, '
        'got $brokerFeePercent',
      );
    }
    if (!salesTaxPercent.isFinite || salesTaxPercent < 0) {
      throw ArgumentError(
        'salesTaxPercent must be finite and non-negative, '
        'got $salesTaxPercent',
      );
    }
    if ((brokerFeePercent + salesTaxPercent) >= 100) {
      throw ArgumentError(
        'brokerFeePercent + salesTaxPercent must be less than 100, '
        'got ${brokerFeePercent + salesTaxPercent}',
      );
    }
  }
}

/// Immutable value object holding a trade's margin calculation results.
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

  /// Whether the trade yields a positive profit.
  bool get isProfitable => profit > 0;
}
