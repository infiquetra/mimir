/// Trade margin calculation utilities.
///
/// Implements the Price Calculations section of the market module spec.
class TradeCalculator {
  TradeCalculator._();

  /// Validates common inputs for margin calculations.
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
        'must be greater than zero',
      );
    }
    if (sellPrice != null && sellPrice < 0) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'must be non-negative',
      );
    }
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'must be non-negative',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'must be non-negative',
      );
    }
    if (brokerFeePercent + salesTaxPercent >= 100) {
      throw ArgumentError(
        'brokerFeePercent + salesTaxPercent must be less than 100, '
        'got ${brokerFeePercent + salesTaxPercent}',
      );
    }
  }

  /// Calculates the margin for a trade.
  ///
  /// [buyPrice] is the price paid per unit (must be > 0).
  /// [sellPrice] is the price received per unit (must be >= 0).
  /// [brokerFeePercent] is the broker fee percentage (default 1.0).
  /// [salesTaxPercent] is the sales tax percentage (default 2.0).
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
    final sellNet = sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
    final profit = sellNet - buyTotal;
    final marginPercent = (profit / buyTotal) * 100;
    final brokerFee = buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100;
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

  /// Calculates the break-even sell price for a trade.
  ///
  /// [buyPrice] is the price paid per unit (must be > 0).
  /// [brokerFeePercent] is the broker fee percentage (default 1.0).
  /// [salesTaxPercent] is the sales tax percentage (default 2.0).
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
    final denominator = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    return buyTotal / denominator;
  }
}

/// Immutable value class representing the result of a margin calculation.
class TradeMargin {
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

  final double buyPrice;
  final double sellPrice;
  final double buyTotal;
  final double sellNet;
  final double profit;
  final double marginPercent;
  final double brokerFee;
  final double salesTax;

  /// Returns `true` if the trade is profitable (profit > 0).
  bool get isProfitable => profit > 0;
}
