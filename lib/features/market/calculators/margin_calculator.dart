/// Market trade margin calculator.
///
/// Provides [TradeCalculator.calculateMargin] and
/// [TradeCalculator.breakEvenSellPrice] for EVE Online market trades,
/// following the blueprint specification for buy total, sell net, profit,
/// margin percent, broker fees, and sales tax.
library;

import 'package:mimir/core/logging/logger.dart';

/// Immutable result of a margin calculation.
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

/// Static methods for market trade calculations.
class TradeCalculator {
  /// Calculates the full margin breakdown for a trade.
  ///
  /// [buyPrice] and [sellPrice] must be finite and non-negative.
  /// [brokerFeePercent] defaults to 1.0 (EVE standard).
  /// [salesTaxPercent] defaults to 2.0 (EVE standard).
  /// Combined [brokerFeePercent] + [salesTaxPercent] must be less than 100.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    Log.d('MKT', 'calculateMargin() - START');
    _validateFiniteNonNegative(buyPrice, 'buyPrice');
    _validateFiniteNonNegative(sellPrice, 'sellPrice');
    _validateFiniteNonNegative(brokerFeePercent, 'brokerFeePercent');
    _validateFiniteNonNegative(salesTaxPercent, 'salesTaxPercent');
    _validateCombinedFees(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
    final profit = sellNet - buyTotal;
    final marginPercent = buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;
    final brokerFee =
        buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    Log.d('MKT',
        'calculateMargin → profit: $profit, margin: ${marginPercent.toStringAsFixed(2)}%');

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
  /// [buyPrice] must be finite and non-negative.
  /// Combined [brokerFeePercent] + [salesTaxPercent] must be less than 100.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    Log.d('MKT', 'breakEvenSellPrice() - START');
    _validateFiniteNonNegative(buyPrice, 'buyPrice');
    _validateFiniteNonNegative(brokerFeePercent, 'brokerFeePercent');
    _validateFiniteNonNegative(salesTaxPercent, 'salesTaxPercent');
    _validateCombinedFees(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final result =
        buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100);

    Log.d('MKT', 'breakEvenSellPrice → $result');

    return result;
  }

  static void _validateFiniteNonNegative(double value, String name) {
    if (value.isNaN || value.isInfinite || value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'expected a finite non-negative value',
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
        'expected brokerFeePercent + salesTaxPercent to be less than 100',
      );
    }
  }
}
