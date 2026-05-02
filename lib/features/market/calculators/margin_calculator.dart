/// Immutable result of a margin calculation.
///
/// All fields are [double] and represent ISK amounts or percentages.
class TradeMargin {
  /// The original buy price per unit.
  final double buyPrice;

  /// The target sell price per unit.
  final double sellPrice;

  /// Total cost to buy, including broker fee.
  final double buyTotal;

  /// Net proceeds from selling, after broker fee and sales tax.
  final double sellNet;

  /// Profit (or loss) = sellNet - buyTotal.
  final double profit;

  /// Margin as a percentage of buyTotal.
  final double marginPercent;

  /// Total broker fee paid (buy-side + sell-side).
  final double brokerFee;

  /// Sales tax paid on the sell side.
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

  /// Whether this trade yields a positive profit.
  bool get isProfitable => profit > 0;
}

/// Pure calculation helpers for EVE Online trading.
///
/// All methods are static; use [TradeCalculator.calculateMargin] or
/// [TradeCalculator.breakEvenSellPrice].  The class cannot be
/// instantiated.
class TradeCalculator {
  const TradeCalculator._();

  /// Computes the margin for buying at [buyPrice] and selling at
  /// [sellPrice], applying [brokerFeePercent] and [salesTaxPercent].
  ///
  /// Both rates default to typical EVE values (1.0% broker, 2.0% sales
  /// tax assuming max Accounting skill).
  ///
  /// Throws [ArgumentError] when any argument is out of range:
  /// - [buyPrice] must be > 0.
  /// - [sellPrice] must be >= 0.
  /// - [brokerFeePercent] and [salesTaxPercent] must each be >= 0.
  /// - [brokerFeePercent] + [salesTaxPercent] must be < 100.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateBuyPrice(buyPrice);
    _validateSellPrice(sellPrice);
    _validateFeeAndTax(brokerFeePercent, 'brokerFeePercent');
    _validateFeeAndTax(salesTaxPercent, 'salesTaxPercent');
    _validateCombinedRate(brokerFeePercent, salesTaxPercent);

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

  /// Returns the minimum sell price that yields zero profit for the
  /// given [buyPrice], [brokerFeePercent], and [salesTaxPercent].
  ///
  /// Throws [ArgumentError] when:
  /// - [buyPrice] must be > 0.
  /// - [brokerFeePercent] and [salesTaxPercent] must each be >= 0.
  /// - [brokerFeePercent] + [salesTaxPercent] must be < 100.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateBuyPrice(buyPrice);
    _validateFeeAndTax(brokerFeePercent, 'brokerFeePercent');
    _validateFeeAndTax(salesTaxPercent, 'salesTaxPercent');
    _validateCombinedRate(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    return buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
  }

  // ── validation helpers ──────────────────────────────────────────

  static void _validateBuyPrice(double buyPrice) {
    if (buyPrice <= 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'must be > 0, got $buyPrice',
      );
    }
  }

  static void _validateSellPrice(double sellPrice) {
    if (sellPrice < 0) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'must be >= 0, got $sellPrice',
      );
    }
  }

  static void _validateFeeAndTax(double value, String name) {
    if (value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'must be >= 0, got $value',
      );
    }
  }

  static void _validateCombinedRate(
    double brokerFeePercent,
    double salesTaxPercent,
  ) {
    final combined = brokerFeePercent + salesTaxPercent;
    if (combined >= 100) {
      throw ArgumentError.value(
        combined,
        'brokerFeePercent + salesTaxPercent',
        'must be < 100, got $combined',
      );
    }
  }
}
