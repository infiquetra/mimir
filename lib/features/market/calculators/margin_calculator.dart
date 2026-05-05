import '../../../core/logging/logger.dart';

// Station trading margin calculator for EVE Online market analysis.
//
// Provides static methods to compute buy/sell margins and break-even sell
// prices, accounting for broker fees and sales tax.
//
// Formulas (from mimir-blueprint market spec):
//   buyTotal  = buyPrice × (1 + brokerFeePercent / 100)
//   sellNet   = sellPrice × (1 − brokerFeePercent / 100 − salesTaxPercent / 100)
//   profit    = sellNet − buyTotal
//   marginPercent = buyTotal == 0 ? 0 : (profit / buyTotal) × 100
//   brokerFee = buyPrice × brokerFeePercent / 100 + sellPrice × brokerFeePercent / 100
//   salesTax  = sellPrice × salesTaxPercent / 100
//   breakEven = buyTotal / (1 − brokerFeePercent / 100 − salesTaxPercent / 100)

/// Immutable result of a margin calculation.
class TradeMargin {
  /// The raw buy price per unit (ISK).
  final double buyPrice;

  /// The raw sell price per unit (ISK).
  final double sellPrice;

  /// Total buy cost including broker fee: `buyPrice × (1 + brokerFee%/100)`.
  final double buyTotal;

  /// Net sell proceeds after broker fee and sales tax:
  /// `sellPrice × (1 − brokerFee%/100 − salesTax%/100)`.
  final double sellNet;

  /// Profit or loss: `sellNet − buyTotal`.
  final double profit;

  /// Margin as a percentage of the total buy cost.
  /// Zero when `buyTotal` is zero.
  final double marginPercent;

  /// Combined broker fee on both buy and sell sides (ISK).
  final double brokerFee;

  /// Sales tax on the sell side (ISK).
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

  /// Whether this trade is profitable (profit > 0).
  /// Zero and negative profit are not profitable.
  bool get isProfitable => profit > 0;
}

/// Static calculator for station trading margins and break-even prices.
class TradeCalculator {
  // coverage:ignore-line (static-only class, never instantiated)
  TradeCalculator._();

  // ---------------------------------------------------------------------------
  // Validation helpers
  // ---------------------------------------------------------------------------

  static void _validateAmount(String name, double value) {
    if (value.isNaN || value.isInfinite || value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'expected a finite non-negative value',
      );
    }
  }

  static void _validatePercent(String name, double value) {
    _validateAmount(name, value);
    // percents over 100 are technically valid for individual fee params
  }

  static void _validateCombinedFees(
    double brokerFeePercent,
    double salesTaxPercent,
  ) {
    if (brokerFeePercent + salesTaxPercent >= 100) {
      throw ArgumentError(
        'Combined broker fee and sales tax must be less than 100%; '
        'got brokerFeePercent=$brokerFeePercent, '
        'salesTaxPercent=$salesTaxPercent',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Compute the margin for a trade with the given prices and fees.
  ///
  /// [buyPrice] and [sellPrice] must be finite and non-negative.
  /// [brokerFeePercent] and [salesTaxPercent] default to 1% and 2%
  /// respectively and must sum to less than 100%.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateAmount('buyPrice', buyPrice);
    _validateAmount('sellPrice', sellPrice);
    _validatePercent('brokerFeePercent', brokerFeePercent);
    _validatePercent('salesTaxPercent', salesTaxPercent);
    _validateCombinedFees(brokerFeePercent, salesTaxPercent);

    Log.d('MARKET',
        'calculateMargin(buyPrice=$buyPrice, sellPrice=$sellPrice) - START');

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);

    final profit = sellNet - buyTotal;
    final marginPercent =
        buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;
    final brokerFee = buyPrice * brokerFeePercent / 100 +
        sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    Log.d('MARKET',
        'calculateMargin -> marginPercent=${marginPercent.toStringAsFixed(2)}%, profit=$profit - SUCCESS');

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

  /// Compute the minimum sell price needed to break even after fees.
  ///
  /// Uses the formula: `buyTotal / netSellFactor` where
  /// `buyTotal = buyPrice × (1 + brokerFeePercent/100)` and
  /// `netSellFactor = 1 − brokerFeePercent/100 − salesTaxPercent/100`.
  ///
  /// Throws [ArgumentError] when fees leave no net sell proceeds
  /// (combined fee ≥ 100%).
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateAmount('buyPrice', buyPrice);
    _validatePercent('brokerFeePercent', brokerFeePercent);
    _validatePercent('salesTaxPercent', salesTaxPercent);
    _validateCombinedFees(brokerFeePercent, salesTaxPercent);

    Log.d('MARKET',
        'breakEvenSellPrice(buyPrice=$buyPrice) - START');

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final netSellFactor =
        1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    final result = buyTotal / netSellFactor;

    Log.d('MARKET',
        'breakEvenSellPrice -> $result - SUCCESS');

    return result;
  }
}
