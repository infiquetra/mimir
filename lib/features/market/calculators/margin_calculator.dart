/// Immutable result of a margin calculation.
///
/// Implements the Price Calculations section of the Market Module Specification:
/// calculateMargin and breakEvenSellPrice with broker fees and sales tax.
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

  /// A trade is profitable when profit is strictly positive.
  bool get isProfitable => profit > 0;
}

/// Static calculator for trade margin and break-even pricing.
///
/// All methods are static — no instance state needed. Formulas follow the
/// blueprint Price Calculations spec exactly.
class TradeCalculator {
  TradeCalculator._(); // prevent instantiation

  /// Validates inputs common to both calculateMargin and breakEvenSellPrice.
  ///
  /// Throws [ArgumentError] for any invalid input. [sellPrice] is only
  /// validated when non-null (breakEvenSellPrice doesn't take a sell price).
  static void _validateInputs({
    required double buyPrice,
    double? sellPrice,
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    if (buyPrice <= 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'must be greater than 0 for margin calculation',
      );
    }
    if (sellPrice != null && sellPrice < 0) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'must be greater than or equal to 0 for margin calculation',
      );
    }
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'must be greater than or equal to 0',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'must be greater than or equal to 0',
      );
    }

    final feeMultiplier = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    if (feeMultiplier <= 0) {
      throw ArgumentError(
        'Combined broker fee and sales tax must be less than 100%: '
        'brokerFeePercent=$brokerFeePercent, salesTaxPercent=$salesTaxPercent',
      );
    }
  }

  /// Returns the net fee multiplier after broker fees and sales tax.
  ///
  /// Callers must ensure inputs are already validated.
  static double _feeMultiplier(
    double brokerFeePercent,
    double salesTaxPercent,
  ) {
    return 1 - brokerFeePercent / 100 - salesTaxPercent / 100;
  }

  /// Calculates trade margin between buy and sell prices.
  ///
  /// Formulas (blueprint spec):
  /// - buyTotal = buyPrice × (1 + brokerFeePercent / 100)
  /// - sellNet = sellPrice × (1 - brokerFeePercent / 100 - salesTaxPercent / 100)
  /// - profit = sellNet - buyTotal
  /// - marginPercent = (profit / buyTotal) × 100
  /// - brokerFee = (buyPrice + sellPrice) × brokerFeePercent / 100
  /// - salesTax = sellPrice × salesTaxPercent / 100
  ///
  /// [buyPrice] must be > 0. [sellPrice] must be ≥ 0.
  /// [brokerFeePercent] and [salesTaxPercent] must be ≥ 0 and their
  /// combined total must be < 100.
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
    final feeMultiplier = _feeMultiplier(brokerFeePercent, salesTaxPercent);
    final sellNet = sellPrice * feeMultiplier;
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

  /// Calculates the sell price needed to break even after fees.
  ///
  /// Formula (blueprint spec):
  /// - buyTotal = buyPrice × (1 + brokerFeePercent / 100)
  /// - feeMultiplier = 1 - brokerFeePercent / 100 - salesTaxPercent / 100
  /// - return buyTotal / feeMultiplier
  ///
  /// [buyPrice] must be > 0. [brokerFeePercent] and [salesTaxPercent]
  /// must be ≥ 0 and their combined total must be < 100.
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
    final feeMultiplier = _feeMultiplier(brokerFeePercent, salesTaxPercent);

    return buyTotal / feeMultiplier;
  }
}
