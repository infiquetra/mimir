import 'package:mimir/core/logging/logger.dart';

/// Pure station-trading margin calculator.
///
/// Provides the core arithmetic for evaluating market buy/sell profitability,
/// computing margin percentages, and determining break-even sell prices.
///
/// Uses standard EVE Online station trading formulas:
/// - Broker fee applied to both buy and sell sides
/// - Sales tax applied to sell side only
///
/// All percentages are expressed as doubles (e.g., 1.0 = 1%).
class TradeCalculator {
  /// Calculates the full margin breakdown for a buy-sell pair.
  ///
  /// Returns an immutable [TradeMargin] with computed fields.
  ///
  /// Throws [ArgumentError] if any input is negative, non-finite, or
  /// the combined sell-side fees (broker + sales tax) reach 100% or above.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    Log.d('CALC', 'calculateMargin entry (buyPrice=$buyPrice, sellPrice=$sellPrice, brokerFee=$brokerFeePercent%, salesTax=$salesTaxPercent%)');
    _validatePrice(buyPrice, 'buyPrice');
    _validatePrice(sellPrice, 'sellPrice');
    _validateFeePercent(brokerFeePercent, 'brokerFeePercent');
    _validateFeePercent(salesTaxPercent, 'salesTaxPercent');
    _validateTotalSellFee(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
    final profit = sellNet - buyTotal;
    final marginPercent = buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;
    final brokerFee =
        buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    Log.d('CALC', 'calculateMargin success (profit=$profit, margin=$marginPercent%)');
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

  /// Computes the minimum sell price needed to break even after fees.
  ///
  /// Throws [ArgumentError] if [buyPrice], [brokerFeePercent], or
  /// [salesTaxPercent] are invalid, or if the combined sell-side
  /// fees reach 100% or above (making break-even impossible).
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    Log.d('CALC', 'breakEvenSellPrice entry (buyPrice=$buyPrice, brokerFee=$brokerFeePercent%, salesTax=$salesTaxPercent%)');
    _validatePrice(buyPrice, 'buyPrice');
    _validateFeePercent(brokerFeePercent, 'brokerFeePercent');
    _validateFeePercent(salesTaxPercent, 'salesTaxPercent');
    _validateTotalSellFee(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final denominator = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    final result = buyTotal / denominator;
    Log.d('CALC', 'breakEvenSellPrice success (result=$result)');
    return result;
  }

  /// Validates that [value] is finite and non-negative.
  ///
  /// Throws [ArgumentError] if [value] is NaN, infinite, or less than zero.
  static void _validatePrice(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        name,
        'expected finite, got $value',
      );
    }
    if (value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'expected >= 0, got $value',
      );
    }
  }

  /// Validates that [value] is a finite, non-negative fee percentage.
  ///
  /// Throws [ArgumentError] if [value] is NaN, infinite, or less than zero.
  static void _validateFeePercent(double value, String name) {
    _validatePrice(value, name);
  }

  /// Ensures the combined sell-side fees are below 100%.
  ///
  /// Throws [ArgumentError] if [brokerFeePercent + salesTaxPercent] >= 100.
  static void _validateTotalSellFee(
    double brokerFeePercent,
    double salesTaxPercent,
  ) {
    final total = brokerFeePercent + salesTaxPercent;
    if (total >= 100) {
      throw ArgumentError.value(
        total,
        'brokerFeePercent + salesTaxPercent',
        'expected < 100, got $total',
      );
    }
  }
}

/// Immutable result of a margin calculation.
///
/// All fields are final doubles; [isProfitable] is a derived getter
/// returning `true` when [profit] is strictly positive.
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

  /// Whether this trade produces a positive profit.
  bool get isProfitable => profit > 0;
}
