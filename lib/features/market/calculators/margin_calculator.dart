/// Market module — Price Calculations / Trade Calculator margin formulas.
///
/// Implements the station-trading margin calculator and break-even sell
/// price formula defined in the mimir-blueprint market specification.
///
/// All public functions validate inputs before computing and throw
/// [ArgumentError] on invalid money values, percentage values, or
/// sell-side fee combinations that would produce a negative denominator.
library;

// No third-party imports — uses only Dart core.

/// Private input validation helpers.

void _validateMoney(String name, double value) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'must be a finite non-negative number');
  }
}

void _validatePercent(String name, double value) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'must be a finite non-negative percentage');
  }
}

void _validateSellCostRate(double brokerFeePercent, double salesTaxPercent) {
  final combined = brokerFeePercent + salesTaxPercent;
  if (combined >= 100) {
    throw ArgumentError.value(
      combined,
      'brokerFeePercent + salesTaxPercent',
      'must be less than 100 so sell net remains positive',
    );
  }
}

/// Station-trading margin calculator.
///
/// A static namespace. Not meant to be instantiated — call the public static
/// methods directly.
final class TradeCalculator {
  const TradeCalculator._();

  /// Calculate profit margin for station trading.
  ///
  /// [buyPrice] and [sellPrice] must be finite, non-negative numbers.
  /// [brokerFeePercent] and [salesTaxPercent] must be finite, non-negative
  /// percentages whose sum is strictly less than 100.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateMoney('buyPrice', buyPrice);
    _validateMoney('sellPrice', sellPrice);
    _validatePercent('brokerFeePercent', brokerFeePercent);
    _validatePercent('salesTaxPercent', salesTaxPercent);
    _validateSellCostRate(brokerFeePercent, salesTaxPercent);

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

  /// Calculate break-even sell price.
  ///
  /// Returns the sell price at which [calculateMargin] would yield a profit
  /// of zero and `marginPercent` of zero (assuming the same default or
  /// custom fee percentages are used on both sides of the trade).
  ///
  /// [buyPrice] must be a finite, non-negative number.
  /// [brokerFeePercent] and [salesTaxPercent] share the same validation as
  /// in [calculateMargin].
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateMoney('buyPrice', buyPrice);
    _validatePercent('brokerFeePercent', brokerFeePercent);
    _validatePercent('salesTaxPercent', salesTaxPercent);
    _validateSellCostRate(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    return buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
  }
}

/// Result model returned by [TradeCalculator.calculateMargin].
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

  /// Whether the trade is profitable (profit > 0).
  bool get isProfitable => profit > 0;
}
