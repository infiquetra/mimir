/// Immutable result of a margin calculation.
///
/// All fields are final doubles representing the trade's financials
/// in ISK (or whatever the caller uses).
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

  /// True when the trade yields a positive profit.
  bool get isProfitable => profit > 0;
}

/// Pure market margin calculator matching the market module
/// specification's [TradeCalculator] behavior.
///
/// All public methods are static; this class is not meant to be
/// instantiated.
class TradeCalculator {
  // Private constructor — this class is only used statically.
  TradeCalculator._();

  /// Returns the margin breakdown for a trade with the given
  /// [buyPrice] and [sellPrice].
  ///
  /// Defaults: 1.0% broker fee, 2.0% sales tax.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePrice(buyPrice, 'buyPrice');
    _validatePrice(sellPrice, 'sellPrice');
    _validateFeePercent(brokerFeePercent, 'brokerFeePercent');
    _validateFeePercent(salesTaxPercent, 'salesTaxPercent');
    _validateCombinedFees(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
    final profit = sellNet - buyTotal;
    final marginPercent = (profit / buyTotal) * 100;

    // Broker fee is charged on both sides.
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

  /// Returns the sell price at which profit is exactly zero for the
  /// given [buyPrice], after accounting for broker fees and sales tax.
  ///
  /// Defaults: 1.0% broker fee, 2.0% sales tax.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePrice(buyPrice, 'buyPrice');
    _validateFeePercent(brokerFeePercent, 'brokerFeePercent');
    _validateFeePercent(salesTaxPercent, 'salesTaxPercent');
    _validateCombinedFees(brokerFeePercent, salesTaxPercent);

    // Break-even: buyTotal == sellNet
    // buyPrice * (1 + bf/100) = sellPrice * (1 - bf/100 - st/100)
    // sellPrice = buyPrice * (1 + bf/100) / (1 - bf/100 - st/100)
    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final denominator = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    return buyTotal / denominator;
  }

  // --- Validators -------------------------------------------------

  static void _validatePrice(double value, String name) {
    if (value <= 0 || value.isNaN || value.isInfinite) {
      throw ArgumentError.value(
        value,
        name,
        'must be a finite positive number',
      );
    }
  }

  static void _validateFeePercent(double value, String name) {
    if (value < 0 || value.isNaN || value.isInfinite) {
      throw ArgumentError.value(
        value,
        name,
        'must be a finite non-negative percent (0-100)',
      );
    }
  }

  static void _validateCombinedFees(
    double brokerFeePercent,
    double salesTaxPercent,
  ) {
    final denominator = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    if (denominator <= 0) {
      throw ArgumentError.value(
        brokerFeePercent + salesTaxPercent,
        'brokerFeePercent + salesTaxPercent',
        'combined broker fee and sales tax must be less than 100% '
            '(got $brokerFeePercent% + $salesTaxPercent% = '
            '${brokerFeePercent + salesTaxPercent}%)',
      );
    }
  }
}
