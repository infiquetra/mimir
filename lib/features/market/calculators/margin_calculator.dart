/// Value object holding a trade's margin calculation result.
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

/// Pure calculator for trade margin and break-even sell price.
class TradeCalculator {
  TradeCalculator._(); // static-only, prevent instantiation

  /// Validates a value is finite and non-negative.
  static void _validateNonNegativeFinite(String name, double value) {
    if (value.isNaN || value.isInfinite || value < 0) {
      print(
          '[MARGIN] Validation failed: $name=$value (must be finite, non-negative)');
      throw ArgumentError.value(
        value,
        name,
        'must be finite and greater than or equal to 0',
      );
    }
  }

  /// Computes the sell-side multiplier and ensures the combined fees
  /// don't consume 100% or more of the sell price.
  static double _validateSellFeeRate({
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    final multiplier = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    if (multiplier <= 0) {
      print(
          '[MARGIN] Combined fees exceed 100%; brokerFeePercent=$brokerFeePercent, salesTaxPercent=$salesTaxPercent');
      throw ArgumentError(
        'Combined sell-side broker fee and sales tax must be less than '
        '100%; got brokerFeePercent=$brokerFeePercent, '
        'salesTaxPercent=$salesTaxPercent',
      );
    }
    return multiplier;
  }

  /// Calculates the margin for a trade given buy/sell prices and fee rates.
  ///
  /// [brokerFeePercent] and [salesTaxPercent] default to 1.0% and 2.0%
  /// respectively, matching the EVE Online in-game defaults.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    print(
        '[MARGIN] calculateMargin entry: buyPrice=$buyPrice, sellPrice=$sellPrice, brokerFeePercent=$brokerFeePercent, salesTaxPercent=$salesTaxPercent');
    _validateNonNegativeFinite('buyPrice', buyPrice);
    _validateNonNegativeFinite('sellPrice', sellPrice);
    _validateNonNegativeFinite('brokerFeePercent', brokerFeePercent);
    _validateNonNegativeFinite('salesTaxPercent', salesTaxPercent);

    final sellMultiplier = _validateSellFeeRate(
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet = sellPrice * sellMultiplier;
    final profit = sellNet - buyTotal;
    final double marginPercent =
        buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;
    final brokerFee =
        buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    print(
        '[MARGIN] calculateMargin result: profit=$profit, marginPercent=$marginPercent, isProfitable=${profit > 0}');
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

  /// Returns the sell price needed to break even (profit = 0).
  ///
  /// Formula: `buyPrice × (1 + brokerFee% / 100) / (1 − brokerFee% / 100 − salesTax% / 100)`
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    print(
        '[MARGIN] breakEvenSellPrice entry: buyPrice=$buyPrice, brokerFeePercent=$brokerFeePercent, salesTaxPercent=$salesTaxPercent');
    _validateNonNegativeFinite('buyPrice', buyPrice);
    _validateNonNegativeFinite('brokerFeePercent', brokerFeePercent);
    _validateNonNegativeFinite('salesTaxPercent', salesTaxPercent);

    final sellMultiplier = _validateSellFeeRate(
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

    final result = buyPrice * (1 + brokerFeePercent / 100) / sellMultiplier;
    print('[MARGIN] breakEvenSellPrice result: $result');
    return result;
  }
}
