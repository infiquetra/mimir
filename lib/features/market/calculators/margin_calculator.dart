/// Market margin calculator for trade profit analysis.
///
/// Provides pure-Dart calculations for trade margins, break-even prices,
/// and fee breakdowns following the mimir-blueprint Price Calculations spec.
///
/// All methods are static and deterministic — no side effects, no I/O.
library;

import '../../../core/logging/logger.dart';

/// Immutable result model for a trade margin calculation.
class TradeMargin {
  /// Original buy price per unit.
  final double buyPrice;

  /// Original sell price per unit.
  final double sellPrice;

  /// Total buy cost including broker fee: `buyPrice * (1 + brokerFeePercent / 100)`.
  final double buyTotal;

  /// Net sell proceeds after fees: `sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100)`.
  final double sellNet;

  /// Profit (or loss): `sellNet - buyTotal`.
  final double profit;

  /// Profit as a percentage of buyTotal: `(profit / buyTotal) * 100`.
  final double marginPercent;

  /// Total broker fees on both sides: `buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100`.
  final double brokerFee;

  /// Sales tax on the sell side: `sellPrice * salesTaxPercent / 100`.
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

  /// Whether the trade produces a profit.
  /// Zero profit is NOT considered profitable (exact break-even).
  bool get isProfitable => profit > 0;
}

/// Stateless calculator for trade margins and break-even prices.
///
/// Non-instantiable — use the static methods directly:
/// ```dart
/// final margin = TradeCalculator.calculateMargin(buyPrice: 100, sellPrice: 150);
/// final breakEven = TradeCalculator.breakEvenSellPrice(buyPrice: 100);
/// ```
class TradeCalculator {
  TradeCalculator._();

  /// Calculates the trade margin for a given buy/sell price pair.
  ///
  /// Default fees match EVE Online's typical rates:
  /// - [brokerFeePercent] defaults to 1.0
  /// - [salesTaxPercent] defaults to 2.0
  ///
  /// Throws [ArgumentError] for invalid inputs:
  /// - buyPrice must be > 0
  /// - sellPrice must be >= 0
  /// - brokerFeePercent must be >= 0
  /// - salesTaxPercent must be >= 0
  /// - Combined sell-side fees must be < 100
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    Log.d(
      'MARKET',
      'calculateMargin(buyPrice: $buyPrice, sellPrice: $sellPrice, '
          'brokerFeePercent: $brokerFeePercent, salesTaxPercent: $salesTaxPercent) - START',
    );
    _validateCommon(buyPrice, brokerFeePercent, salesTaxPercent);
    if (sellPrice < 0) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'Expected sellPrice to be 0 or greater',
      );
    }

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellFeeMultiplier =
        1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    final sellNet = sellPrice * sellFeeMultiplier;
    final profit = sellNet - buyTotal;
    final marginPercent = (profit / buyTotal) * 100;
    final brokerFee =
        buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    Log.d(
      'MARKET',
      'calculateMargin - profit: $profit, marginPercent: $marginPercent, '
          'isProfitable: ${profit > 0}',
    );

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

  /// Calculates the break-even sell price where profit = 0.
  ///
  /// This is the minimum sell price needed to cover the buy cost
  /// plus all fees on both sides of the transaction.
  ///
  /// Throws [ArgumentError] for the same invalid-input conditions
  /// as [calculateMargin], plus the combined sell-side fees must be < 100
  /// (otherwise the denominator collapses to zero or negative).
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    Log.d(
      'MARKET',
      'breakEvenSellPrice(buyPrice: $buyPrice, brokerFeePercent: $brokerFeePercent, '
          'salesTaxPercent: $salesTaxPercent) - START',
    );
    _validateCommon(buyPrice, brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellFeeMultiplier =
        1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    final breakEvenPrice = buyTotal / sellFeeMultiplier;
    Log.d('MARKET', 'breakEvenSellPrice - breakEvenPrice: $breakEvenPrice');
    return breakEvenPrice;
  }

  /// Validates parameters shared by both calculation methods.
  static void _validateCommon(
    double buyPrice,
    double brokerFeePercent,
    double salesTaxPercent,
  ) {
    if (buyPrice <= 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'Expected buyPrice to be greater than 0',
      );
    }
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'Expected brokerFeePercent to be 0 or greater',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'Expected salesTaxPercent to be 0 or greater',
      );
    }
    final sellFeeMultiplier =
        1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    if (sellFeeMultiplier <= 0) {
      throw ArgumentError.value(
        brokerFeePercent + salesTaxPercent,
        'brokerFeePercent + salesTaxPercent',
        'Expected combined sell-side fees to be less than 100',
      );
    }
  }
}
