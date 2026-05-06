/// Pure Dart margin calculator for EVE Online market trading.
///
/// Implements the Market Module Specification's Price Calculations section:
/// profit/loss analysis, break-even sell price, and trade profitability checks.
library;

import 'package:mimir/core/logging/logger.dart';

// ---------------------------------------------------------------------------
// Input validation helpers
// ---------------------------------------------------------------------------

void _validateNonNegativeFinite(double value, String name) {
  if (value.isNaN || value.isInfinite) {
    throw ArgumentError.value(value, name, 'must be a finite number');
  }
  if (value < 0) {
    throw ArgumentError.value(value, name, 'must be >= 0');
  }
}

void _validateFeeRates(double brokerFeePercent, double salesTaxPercent) {
  _validateNonNegativeFinite(brokerFeePercent, 'brokerFeePercent');
  _validateNonNegativeFinite(salesTaxPercent, 'salesTaxPercent');

  if (brokerFeePercent + salesTaxPercent >= 100) {
    throw ArgumentError.value(
      brokerFeePercent,
      'brokerFeePercent',
      'brokerFeePercent ($brokerFeePercent) + salesTaxPercent '
          '($salesTaxPercent) must be < 100',
    );
  }
}

// ---------------------------------------------------------------------------
// Result model
// ---------------------------------------------------------------------------

/// Immutable result of a trade margin calculation.
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

  /// Whether the trade is profitable (strictly positive profit).
  bool get isProfitable => profit > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeMargin &&
          buyPrice == other.buyPrice &&
          sellPrice == other.sellPrice &&
          buyTotal == other.buyTotal &&
          sellNet == other.sellNet &&
          profit == other.profit &&
          marginPercent == other.marginPercent &&
          brokerFee == other.brokerFee &&
          salesTax == other.salesTax;

  @override
  int get hashCode => Object.hash(
    buyPrice,
    sellPrice,
    buyTotal,
    sellNet,
    profit,
    marginPercent,
    brokerFee,
    salesTax,
  );

  @override
  String toString() =>
      'TradeMargin('
      'buyPrice: $buyPrice, '
      'sellPrice: $sellPrice, '
      'buyTotal: $buyTotal, '
      'sellNet: $sellNet, '
      'profit: $profit, '
      'marginPercent: $marginPercent, '
      'brokerFee: $brokerFee, '
      'salesTax: $salesTax, '
      'isProfitable: $isProfitable'
      ')';
}

// ---------------------------------------------------------------------------
// Calculator
// ---------------------------------------------------------------------------

/// Pure calculator for EVE Online trade margin analysis.
class TradeCalculator {
  // coverage:ignore-line — private ctor prevents instantiation; untestable
  TradeCalculator._();

  /// Computes the full margin breakdown for a potential trade.
  ///
  /// [buyPrice] and [sellPrice] represent the per-unit ISK values
  /// before fees.  [brokerFeePercent] and [salesTaxPercent] default
  /// to the EVE Online baseline (1.0 % broker, 2.0 % sales tax) but
  /// can be overridden for skills-adjusted scenarios.
  ///
  /// Throws [ArgumentError] if any input is invalid.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    Log.d('TradeCalculator', 'calculateMargin: buyPrice=$buyPrice, sellPrice=$sellPrice');
    _validateNonNegativeFinite(buyPrice, 'buyPrice');
    _validateNonNegativeFinite(sellPrice, 'sellPrice');
    _validateFeeRates(brokerFeePercent, salesTaxPercent);

    final buyBrokerFee = buyPrice * brokerFeePercent / 100;
    final sellBrokerFee = sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    final buyTotal = buyPrice + buyBrokerFee;
    final sellNet = sellPrice - sellBrokerFee - salesTax;

    final profit = sellNet - buyTotal;
    final marginPercent = buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;
    final brokerFee = buyBrokerFee + sellBrokerFee;

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

  /// Minimum sell price required to break even on a purchase.
  ///
  /// Returns the per-unit ISK price at which [calculateMargin] would
  /// report a profit of exactly 0 after broker fees and sales tax.
  ///
  /// Throws [ArgumentError] if any input is invalid.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    Log.d('TradeCalculator', 'breakEvenSellPrice: buyPrice=$buyPrice');
    _validateNonNegativeFinite(buyPrice, 'buyPrice');
    _validateFeeRates(brokerFeePercent, salesTaxPercent);

    if (buyPrice == 0) return 0.0;

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final netSellMultiplier =
        1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    return buyTotal / netSellMultiplier;
  }
}
