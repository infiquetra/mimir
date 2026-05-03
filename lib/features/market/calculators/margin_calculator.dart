/// Static utility for trade margin calculations.
///
/// All methods follow the EVE Online market specification for
/// broker fees (applied to both buy and sell sides) and sales tax
/// (applied to sell side only).
class TradeCalculator {
  TradeCalculator._(); // static utility — no instance needed

  /// Calculates the trade margin for a buy/sell pair.
  ///
  /// [buyPrice] and [sellPrice] must both be finite ISK values
  /// greater than zero.
  ///
  /// [brokerFeePercent] and [salesTaxPercent] must both be finite
  /// values ≥ 0, and their sum must be less than 100 (otherwise the
  /// sell-side net and break-even price are undefined).
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

  /// Returns the sell price at which profit is exactly zero for a
  /// given buy price and fee structure.
  ///
  /// [buyPrice] must be a finite ISK value greater than zero.
  ///
  /// [brokerFeePercent] and [salesTaxPercent] must both be finite
  /// values ≥ 0, and their sum must be less than 100.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePrice(buyPrice, 'buyPrice');
    _validateFeePercent(brokerFeePercent, 'brokerFeePercent');
    _validateFeePercent(salesTaxPercent, 'salesTaxPercent');
    _validateCombinedFees(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final denominator = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    return buyTotal / denominator;
  }

  // --- private validators ---

  static void _validatePrice(double value, String name) {
    if (value <= 0 || !value.isFinite) {
      throw ArgumentError.value(
        value,
        name,
        'Expected a finite ISK price greater than 0',
      );
    }
  }

  static void _validateFeePercent(double value, String name) {
    if (value < 0 || !value.isFinite) {
      throw ArgumentError.value(
        value,
        name,
        'Expected a finite percentage greater than or equal to 0',
      );
    }
  }

  static void _validateCombinedFees(
    double brokerFeePercent,
    double salesTaxPercent,
  ) {
    final combined = brokerFeePercent + salesTaxPercent;
    if (combined >= 100) {
      throw ArgumentError.value(
        combined,
        'combinedFeePercent',
        'Expected brokerFeePercent + salesTaxPercent to be less than '
            '100 so sell net and break-even price are defined',
      );
    }
  }
}

/// Immutable result of a trade margin calculation.
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

  /// Returns `true` when [profit] is strictly greater than zero.
  ///
  /// An exactly-zero-profit (break-even) trade is considered NOT
  /// profitable.
  bool get isProfitable => profit > 0;
}
