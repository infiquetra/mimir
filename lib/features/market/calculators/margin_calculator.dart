/// Margin calculator for EVE Online trading.
///
/// Provides margin calculation and break-even sell price analysis
/// for buy/sell trades with configurable broker fees and sales tax.
///
/// Based on mimir-blueprint platform-specs/03-feature-modules/market/specification.md
/// Price Calculations section.

library;

import 'package:mimir/core/logging/logger.dart';

/// Immutable result of a margin calculation.
class MarginResult {
  final double buyPrice;
  final double sellPrice;
  final double buyTotal;
  final double sellNet;
  final double profit;
  final double marginPercent;
  final double brokerFee;
  final double salesTax;

  const MarginResult({
    required this.buyPrice,
    required this.sellPrice,
    required this.buyTotal,
    required this.sellNet,
    required this.profit,
    required this.marginPercent,
    required this.brokerFee,
    required this.salesTax,
  });

  /// Returns true when the trade is profitable (profit > 0).
  bool get isProfitable => profit > 0;
}

/// Margin calculation utilities for EVE Online trading.
///
/// Handles broker fees (applied to both buy and sell sides)
/// and sales tax (applied only to the sell side).
class MarginCalculator {
  MarginCalculator._(); // Prevent instantiation.

  /// Calculates the full margin breakdown for a buy/sell pair.
  ///
  /// [buyPrice], [sellPrice], [brokerFeePercent], and [salesTaxPercent]
  /// must all be finite and non-negative. Combined sell-side fees at or
  /// above 100% are accepted and produce zero or negative sell-net results.
  ///
  /// Returns a [MarginResult] with the full breakdown.
  static MarginResult calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateFiniteNonNegative('buyPrice', buyPrice);
    _validateFiniteNonNegative('sellPrice', sellPrice);
    _validateFiniteNonNegative('brokerFeePercent', brokerFeePercent);
    _validateFiniteNonNegative('salesTaxPercent', salesTaxPercent);

    Log.d('MARKET', 'calculateMargin called');

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
    final profit = sellNet - buyTotal;
    final marginPercent =
        buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;
    final brokerFee =
        buyPrice * brokerFeePercent / 100 +
        sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    return MarginResult(
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

  /// Calculates the sell price at which profit is exactly zero.
  ///
  /// All inputs must be finite and non-negative. Additionally,
  /// [brokerFeePercent] + [salesTaxPercent] must be less than 100%,
  /// since at or above 100% combined fees the concept of a break-even
  /// price is invalid.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateFiniteNonNegative('buyPrice', buyPrice);
    _validateFiniteNonNegative('brokerFeePercent', brokerFeePercent);
    _validateFiniteNonNegative('salesTaxPercent', salesTaxPercent);
    _validateBreakEvenSellFees(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final breakEven =
        buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100);

    Log.d('MARKET', 'breakEvenSellPrice calculated');

    return breakEven;
  }
}

/// Validates that [value] is finite and non-negative.
void _validateFiniteNonNegative(String parameterName, double value) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(
      value,
      parameterName,
      'Expected a finite non-negative value',
    );
  }
}

/// Validates that combined sell-side fees are below 100%.
///
/// Only used by [MarginCalculator.breakEvenSellPrice], where a
/// zero or negative denominator makes the break-even concept invalid.
void _validateBreakEvenSellFees(
  double brokerFeePercent,
  double salesTaxPercent,
) {
  final combined = brokerFeePercent + salesTaxPercent;
  if (combined >= 100) {
    throw ArgumentError.value(
      combined,
      'brokerFeePercent + salesTaxPercent',
      'Expected combined sell fees below 100% for break-even calculation',
    );
  }
}
