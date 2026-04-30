/// Result of a trade margin calculation.
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

  /// Returns true when the trade generates a profit (profit > 0).
  bool get isProfitable => profit > 0;
}

/// Calculator for EVE Online trade margin and break-even analysis.
///
/// Implements the Market Module Specification → Price Calculations.
class TradeCalculator {
  const TradeCalculator._();

  /// Calculates the trade margin for a given buy/sell scenario.
  ///
  /// [buyPrice] and [sellPrice] must be >= 0.
  /// [brokerFeePercent] and [salesTaxPercent] must be >= 0 and their sum
  /// must be less than 100.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePrice(buyPrice, 'buyPrice');
    _validatePrice(sellPrice, 'sellPrice');
    _validatePercent(brokerFeePercent, 'brokerFeePercent');
    _validatePercent(salesTaxPercent, 'salesTaxPercent');
    _validateDeductionSum(brokerFeePercent, salesTaxPercent);

    // buyTotal = buyPrice * (1 + brokerFeePercent / 100)
    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);

    // sellNet = sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100)
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);

    // profit = sellNet - buyTotal
    final profit = sellNet - buyTotal;

    // marginPercent = (profit / buyTotal) * 100, with zero-buy guard
    final double marginPercent =
        buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;

    // brokerFee = buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100
    final brokerFee = buyPrice * brokerFeePercent / 100 +
        sellPrice * brokerFeePercent / 100;

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

  /// Calculates the minimum sell price needed to break even.
  ///
  /// Formula: breakEvenSellPrice = buyTotal / (1 - brokerFeePercent/100 - salesTaxPercent/100)
  ///
  /// [buyPrice] must be >= 0.
  /// [brokerFeePercent] and [salesTaxPercent] must be >= 0 and their sum
  /// must be less than 100.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePrice(buyPrice, 'buyPrice');
    _validatePercent(brokerFeePercent, 'brokerFeePercent');
    _validatePercent(salesTaxPercent, 'salesTaxPercent');
    _validateDeductionSum(brokerFeePercent, salesTaxPercent);

    if (buyPrice == 0) return 0;

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final denominator = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    return buyTotal / denominator;
  }

  static void _validatePrice(double value, String name) {
    if (value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'must be greater than or equal to 0',
      );
    }
  }

  static void _validatePercent(double value, String name) {
    if (value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'must be greater than or equal to 0',
      );
    }
  }

  static void _validateDeductionSum(
      double brokerFeePercent, double salesTaxPercent) {
    final sum = brokerFeePercent + salesTaxPercent;
    if (sum >= 100) {
      throw ArgumentError(
        'brokerFeePercent + salesTaxPercent must be less than 100; got $sum',
      );
    }
  }
}
