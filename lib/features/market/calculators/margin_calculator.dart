import 'package:mimir/core/logging/logger.dart';

/// Margin calculation utilities for EVE Online trading.
///
/// Implements the standard station-trading formulas with broker fees
/// and sales tax, per the Market Module Specification.
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

  /// Returns true if the trade would earn a positive profit.
  bool get isProfitable => profit > 0;
}

/// Pure calculator for station-trading margin and break-even analysis.
class TradeCalculator {
  // ignore: unused_element — static-only utility class, no instance needed
  TradeCalculator._();

  /// Calculates the margin for a trade with the given prices and fees.
  ///
  /// [buyPrice] — unit price at purchase.
  /// [sellPrice] — unit price at sale.
  /// [brokerFeePercent] — broker fee as a percentage (default 1.0).
  /// [salesTaxPercent] — sales tax as a percentage (default 2.0).
  ///
  /// Throws [ArgumentError] if any price is negative, any fee/tax
  /// percentage is negative, broker + tax consume the entire
  /// sell price (making the denominator non-positive), or buyPrice
  /// is zero (which would produce an infinite marginPercent).
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    Log.d('MARKET', 'calculateMargin — buy: $buyPrice, sell: $sellPrice, '
        'broker: $brokerFeePercent%, tax: $salesTaxPercent%');

    _validatePrices(buyPrice: buyPrice, sellPrice: sellPrice);
    if (buyPrice == 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'expected a positive ISK price (zero would produce an infinite margin)',
      );
    }
    _validateFees(
        brokerFeePercent: brokerFeePercent, salesTaxPercent: salesTaxPercent);
    _validateDenominator(
        brokerFeePercent: brokerFeePercent, salesTaxPercent: salesTaxPercent);

    final brokerFeeRate = brokerFeePercent / 100;
    final salesTaxRate = salesTaxPercent / 100;

    final buyTotal = buyPrice * (1 + brokerFeeRate);
    final sellNet = sellPrice * (1 - brokerFeeRate - salesTaxRate);
    final profit = sellNet - buyTotal;
    final marginPercent = (profit / buyTotal) * 100;
    final brokerFee =
        (buyPrice * brokerFeeRate) + (sellPrice * brokerFeeRate);
    final salesTax = sellPrice * salesTaxRate;

    Log.d('MARKET', 'calculateMargin — profit: $profit, margin: $marginPercent%');

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

  /// Calculates the sell price at which a trade breaks even.
  ///
  /// The formula computes the sell price where `profit == 0` given
  /// the buy price and fee structure:
  ///   buyTotal = buyPrice * (1 + brokerFeePercent / 100)
  ///   result = buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100)
  ///
  /// Throws [ArgumentError] if [buyPrice] is negative or zero, any fee/tax
  /// percentage is negative, or broker + tax consume the denominator.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    Log.d('MARKET', 'breakEvenSellPrice — buy: $buyPrice, '
        'broker: $brokerFeePercent%, tax: $salesTaxPercent%');

    if (buyPrice <= 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'expected a positive ISK price',
      );
    }
    _validateFees(
        brokerFeePercent: brokerFeePercent, salesTaxPercent: salesTaxPercent);
    _validateDenominator(
        brokerFeePercent: brokerFeePercent, salesTaxPercent: salesTaxPercent);

    final brokerFeeRate = brokerFeePercent / 100;
    final salesTaxRate = salesTaxPercent / 100;

    final buyTotal = buyPrice * (1 + brokerFeeRate);
    return buyTotal / (1 - brokerFeeRate - salesTaxRate);
  }

  // ─── validation helpers ────────────────────────────────────────

  static void _validatePrices({
    required double buyPrice,
    required double sellPrice,
  }) {
    if (buyPrice < 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'expected a non-negative ISK price',
      );
    }
    if (sellPrice < 0) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'expected a non-negative ISK price',
      );
    }
  }

  static void _validateFees({
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'expected a non-negative percentage',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'expected a non-negative percentage',
      );
    }
  }

  static void _validateDenominator({
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    if (brokerFeePercent + salesTaxPercent >= 100) {
      throw ArgumentError(
        'Invalid market fees: expected brokerFeePercent + salesTaxPercent '
        'to be less than 100, got ${brokerFeePercent + salesTaxPercent}',
      );
    }
  }
}
