/// Trade margin calculation utilities for market trading analysis.
library;

/// Immutable value object representing the margin analysis of a trade.
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

  /// Returns true if the trade generated a positive profit.
  bool get isProfitable => profit > 0;
}

/// Static calculator for trade margin and break-even analysis.
class TradeCalculator {
  TradeCalculator._();

  /// Calculates the full margin analysis for a trade.
  ///
  /// [buyPrice] is the purchase price of the item.
  /// [sellPrice] is the selling price of the item.
  /// [brokerFeePercent] is the broker fee percentage applied to both buy and sell (default 1.0).
  /// [salesTaxPercent] is the sales tax percentage applied to the sell price (default 2.0).
  ///
  /// Throws [ArgumentError] if any input is not finite, if buyPrice <= 0,
  /// or if sellPrice, brokerFeePercent, or salesTaxPercent is negative.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateFinitePositive(buyPrice, 'buyPrice');
    _validateFiniteNonNegative(sellPrice, 'sellPrice');
    _validateFiniteNonNegative(brokerFeePercent, 'brokerFeePercent');
    _validateFiniteNonNegative(salesTaxPercent, 'salesTaxPercent');

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

  /// Calculates the break-even sell price that covers all costs and fees.
  ///
  /// [buyPrice] is the purchase price of the item.
  /// [brokerFeePercent] is the broker fee percentage applied to both buy and sell (default 1.0).
  /// [salesTaxPercent] is the sales tax percentage applied to the sell price (default 2.0).
  ///
  /// Throws [ArgumentError] if any input is not finite, if buyPrice <= 0,
  /// if either percentage is negative, or if fees consume the entire sell price.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateFinitePositive(buyPrice, 'buyPrice');
    _validateFiniteNonNegative(brokerFeePercent, 'brokerFeePercent');
    _validateFiniteNonNegative(salesTaxPercent, 'salesTaxPercent');

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellFeeMultiplier =
        1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    if (sellFeeMultiplier <= 0) {
      throw ArgumentError(
        'sellFeeMultiplier must be positive, '
        'but got $sellFeeMultiplier '
        '(brokerFeePercent=$brokerFeePercent, salesTaxPercent=$salesTaxPercent)',
      );
    }

    return buyTotal / sellFeeMultiplier;
  }

  static void _validateFinitePositive(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError('$name must be finite, got $value');
    }
    if (value <= 0) {
      throw ArgumentError('$name must be positive, got $value');
    }
  }

  static void _validateFiniteNonNegative(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError('$name must be finite, got $value');
    }
    if (value < 0) {
      throw ArgumentError('$name must be non-negative, got $value');
    }
  }
}
