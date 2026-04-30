/// Result of a trade margin calculation.
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

/// Pure-Dart calculator for trade margin and break-even analysis.
///
/// Implements the [Market module spec's Price Calculations][spec] section.
///
/// [spec]: https://github.com/infiquetra/mimir-blueprint/blob/main/platform-specs/03-feature-modules/market/specification.md
class TradeCalculator {
  const TradeCalculator._();

  /// Computes the margin of buying at [buyPrice] and selling at [sellPrice].
  ///
  /// [brokerFeePercent] and [salesTaxPercent] default to 1.0% and 2.0%
  /// respectively, reflecting typical EVE Online broker fees and sales tax.
  ///
  /// Throws [ArgumentError] if any input is negative, or if the combined
  /// sell-side deductions ([brokerFeePercent] + [salesTaxPercent]) are 100%
  /// or greater.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePrice('buyPrice', buyPrice);
    _validatePrice('sellPrice', sellPrice);
    _validateFee('brokerFeePercent', brokerFeePercent);
    _validateFee('salesTaxPercent', salesTaxPercent);
    _validateCombinedDeductions(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet = sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
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

  /// The sell price at which the trade breaks even (profit = 0).
  ///
  /// Returns zero when [buyPrice] is zero (a free item has no cost to
  /// recover).
  ///
  /// Throws [ArgumentError] if [buyPrice] is negative, any fee/tax is
  /// negative, or the combined sell-side deductions are 100% or greater.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePrice('buyPrice', buyPrice);
    _validateFee('brokerFeePercent', brokerFeePercent);
    _validateFee('salesTaxPercent', salesTaxPercent);
    _validateCombinedDeductions(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final denominator = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    return buyTotal / denominator;
  }

  static void _validatePrice(String name, double value) {
    if (value < 0) {
      throw ArgumentError.value(value, name, 'must be >= 0');
    }
  }

  static void _validateFee(String name, double value) {
    if (value < 0) {
      throw ArgumentError.value(value, name, 'must be >= 0');
    }
  }

  static void _validateCombinedDeductions(
      double brokerFeePercent, double salesTaxPercent) {
    if (brokerFeePercent + salesTaxPercent >= 100) {
      throw ArgumentError(
        'brokerFeePercent ($brokerFeePercent) + salesTaxPercent '
        '($salesTaxPercent) = ${brokerFeePercent + salesTaxPercent} '
        'must be < 100',
      );
    }
  }
}
