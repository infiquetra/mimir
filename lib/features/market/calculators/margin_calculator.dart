/// Value object holding all calculated margin fields for a trade.
///
/// All fields are immutable [double] values returned by
/// [TradeCalculator.calculateMargin].
class TradeMargin {
  /// Price at which the item was bought.
  final double buyPrice;

  /// Price at which the item was sold (or is expected to be sold).
  final double sellPrice;

  /// Total cost including broker fee: `buyPrice * (1 + brokerFee% / 100)`.
  final double buyTotal;

  /// Net proceeds after broker fee and sales tax:
  /// `sellPrice * (1 - brokerFee% / 100 - salesTax% / 100)`.
  final double sellNet;

  /// Profit (or loss): `sellNet - buyTotal`.
  final double profit;

  /// Margin as a percentage of buyTotal:
  /// `(profit / buyTotal) * 100`, or `0.0` when buyTotal is zero.
  final double marginPercent;

  /// Total broker fee paid on both sides of the trade.
  final double brokerFee;

  /// Total sales tax paid when selling.
  final double salesTax;

  /// Immutable value object.
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

  /// Whether the trade generated a positive profit.
  bool get isProfitable => profit > 0;
}

/// Stateless utility for computing trade margins and break-even prices.
///
/// All methods are static. Instantiation is forbidden via a private
/// constructor.
class TradeCalculator {
  // coverage:ignore-line — private constructor; class has only static methods
  const TradeCalculator._();

  /// Validates that [value] is finite and non-negative.
  ///
  /// Throws [ArgumentError] if the value is NaN, infinite, or negative.
  static void _validateNonNegative(double value, String paramName) {
    if (value.isNaN || value.isInfinite || value < 0) {
      throw ArgumentError.value(
        value,
        paramName,
        'must be a finite non-negative number',
      );
    }
  }

  /// Calculates margin details for a trade.
  ///
  /// [buyPrice] and [sellPrice] are the per-unit prices.
  /// [brokerFeePercent] defaults to 1.0%; [salesTaxPercent] defaults to 2.0%.
  ///
  /// Returns a [TradeMargin] with all calculated fields.
  ///
  /// Throws [ArgumentError] if any price or fee/tax input is invalid
  /// (NaN, infinite, or negative), or if brokerFeePercent + salesTaxPercent
  /// is >= 100 (which would produce zero or negative sellNet).
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateNonNegative(buyPrice, 'buyPrice');
    _validateNonNegative(sellPrice, 'sellPrice');
    _validateNonNegative(brokerFeePercent, 'brokerFeePercent');
    _validateNonNegative(salesTaxPercent, 'salesTaxPercent');

    final totalFeePercent = brokerFeePercent + salesTaxPercent;
    if (totalFeePercent >= 100) {
      throw ArgumentError.value(
        totalFeePercent,
        'totalFeePercent',
        'must be less than 100',
      );
    }

    // buyTotal = buyPrice * (1 + brokerFeePercent / 100)
    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);

    // sellNet = sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100)
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);

    // profit = sellNet - buyTotal
    final profit = sellNet - buyTotal;

    // marginPercent = (profit / buyTotal) * 100, or 0.0 when buyTotal is zero
    final marginPercent = buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;

    // brokerFee = buy side + sell side
    final brokerFee =
        buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100;

    // salesTax = sellPrice * salesTaxPercent / 100
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

  /// Calculates the sell price needed to break even (profit = 0).
  ///
  /// Formula: `buyPrice * (1 + brokerFeePercent / 100) /
  ///           (1 - brokerFeePercent / 100 - salesTaxPercent / 100)`.
  ///
  /// [buyPrice] is the per-unit purchase price.
  /// [brokerFeePercent] defaults to 1.0%; [salesTaxPercent] defaults to 2.0%.
  ///
  /// Throws [ArgumentError] if [buyPrice] is invalid (NaN, infinite, or
  /// negative), or if brokerFeePercent + salesTaxPercent is >= 100.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateNonNegative(buyPrice, 'buyPrice');
    _validateNonNegative(brokerFeePercent, 'brokerFeePercent');
    _validateNonNegative(salesTaxPercent, 'salesTaxPercent');

    final totalFeePercent = brokerFeePercent + salesTaxPercent;
    if (totalFeePercent >= 100) {
      throw ArgumentError.value(
        totalFeePercent,
        'totalFeePercent',
        'must be less than 100',
      );
    }

    // buyTotal = buyPrice * (1 + brokerFeePercent / 100)
    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);

    // breakEvenSellPrice = buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100)
    return buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
  }
}
