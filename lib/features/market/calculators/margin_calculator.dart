/// Trade calculation result with all margin analysis fields.
final class TradeMargin {
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

  /// A trade is profitable when the net proceeds exceed the total cost.
  bool get isProfitable => profit > 0;
}

/// Static utility for margin and break-even calculations.
final class TradeCalculator {
  const TradeCalculator._();

  /// Validates that [value] is a finite number greater than zero.
  static void _validatePositiveAmount(String name, double value) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(
        value,
        name,
        'must be a finite number greater than zero',
      );
    }
  }

  /// Validates that [value] is a finite percentage greater than or equal to zero.
  static void _validateNonNegativePercent(String name, double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'must be a finite percentage greater than or equal to zero',
      );
    }
  }

  /// Validates that combined sell-side fees leave some net proceeds.
  static void _validateSellFeePercent(
    double brokerFeePercent,
    double salesTaxPercent,
  ) {
    final combined = brokerFeePercent + salesTaxPercent;
    if (combined >= 100) {
      throw ArgumentError.value(
        combined,
        'brokerFeePercent + salesTaxPercent',
        'must be less than 100 so sell proceeds remain positive',
      );
    }
  }

  /// Computes a margin analysis for a trade with the given buy/sell prices
  /// and fee percentages.
  ///
  /// [brokerFeePercent] defaults to 1.0% and [salesTaxPercent] to 2.0%.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePositiveAmount('buyPrice', buyPrice);
    _validatePositiveAmount('sellPrice', sellPrice);
    _validateNonNegativePercent('brokerFeePercent', brokerFeePercent);
    _validateNonNegativePercent('salesTaxPercent', salesTaxPercent);
    _validateSellFeePercent(brokerFeePercent, salesTaxPercent);

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

  /// Computes the break-even sell price for a given [buyPrice] and fee
  /// percentages.
  ///
  /// Returns the minimum price at which selling nets zero profit after
  /// broker fees and sales tax.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePositiveAmount('buyPrice', buyPrice);
    _validateNonNegativePercent('brokerFeePercent', brokerFeePercent);
    _validateNonNegativePercent('salesTaxPercent', salesTaxPercent);
    _validateSellFeePercent(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    return buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
  }
}
