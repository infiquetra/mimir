/// Immutable value object representing the result of a trade margin calculation.
class TradeMargin {
  /// Creates a [TradeMargin] with all computed fields.
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

  /// Whether the trade is profitable (profit strictly greater than zero).
  bool get isProfitable => profit > 0;
}

/// Utility class for calculating trade margins and break-even prices.
///
/// Use the static methods [calculateMargin] and [breakEvenSellPrice].
class TradeCalculator {
  const TradeCalculator._();

  /// Calculates margin details for a station trade.
  ///
  /// [brokerFeePercent] and [salesTaxPercent] are expressed as whole
  /// percentages (e.g. `1.0` means 1%).
  ///
  /// Throws [ArgumentError] for invalid inputs.
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
    final marginPercent = buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;
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

  /// Calculates the minimum sell price required to break even.
  ///
  /// [brokerFeePercent] and [salesTaxPercent] are expressed as whole
  /// percentages (e.g. `1.0` means 1%).
  ///
  /// Throws [ArgumentError] for invalid inputs.
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

    if (denominator <= 0) {
      throw ArgumentError.value(
        brokerFeePercent + salesTaxPercent,
        'brokerFeePercent + salesTaxPercent',
        'Combined fees must be less than 100% and result in a positive denominator',
      );
    }

    return buyTotal / denominator;
  }

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
        'expected a positive value',
      );
    }

    if (sellPrice != null && sellPrice < 0) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'expected a non-negative value',
      );
    }

    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'expected a non-negative value',
      );
    }

    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'expected a non-negative value',
      );
    }

    if (brokerFeePercent + salesTaxPercent >= 100) {
      throw ArgumentError.value(
        brokerFeePercent + salesTaxPercent,
        'brokerFeePercent + salesTaxPercent',
        'Combined fees must be less than 100%',
      );
    }
  }
}
