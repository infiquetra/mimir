/// Market margin calculator for EVE Online station trading.
///
/// Provides pure, static calculations for trade margin analysis and
/// break-even price determination based on the Market Module Specification
/// > Price Calculations section.
library;

import 'dart:developer' show log;

/// Immutable result model for a trade margin calculation.
///
/// Contains all intermediate and final values from a margin calculation.
/// Positive [profit] means the trade is profitable; zero or negative is not.
class TradeMargin {
  /// Original buy price per unit.
  final double buyPrice;

  /// Original sell price per unit.
  final double sellPrice;

  /// Total buy cost including broker fee on the buy side.
  final double buyTotal;

  /// Net sell proceeds after broker fee and sales tax on the sell side.
  final double sellNet;

  /// Profit per unit: [sellNet] minus [buyTotal].
  final double profit;

  /// Profit as a percentage of [buyTotal].
  final double marginPercent;

  /// Total broker fee across both buy and sell sides.
  final double brokerFee;

  /// Sales tax on the sell side only.
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

  /// Whether this trade yields a positive profit.
  bool get isProfitable => profit > 0;
}

/// Pure static calculator for market trade margins and break-even prices.
///
/// All methods are static; do not instantiate. Formulas follow the
/// Market Module Specification > Price Calculations section.
class TradeCalculator {
  TradeCalculator._();

  /// Calculates the trade margin for a station trade.
  ///
  /// [buyPrice] and [sellPrice] must be finite positive values.
  /// [brokerFeePercent] and [salesTaxPercent] must be finite non-negative
  /// values whose sum is strictly less than 100.
  ///
  /// Throws [ArgumentError] for invalid inputs.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateBuyPrice(buyPrice);
    _validateSellPrice(sellPrice);
    _validatePercent(brokerFeePercent, 'brokerFeePercent');
    _validatePercent(salesTaxPercent, 'salesTaxPercent');
    _validateDeductions(brokerFeePercent, salesTaxPercent);

    log(
      'calculateMargin() - START buy=$buyPrice sell=$sellPrice '
      'brokerFee=$brokerFeePercent% tax=$salesTaxPercent%',
      name: 'MARKET',
    );

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
    final profit = sellNet - buyTotal;
    final marginPercent = (profit / buyTotal) * 100;
    final brokerFee =
        buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    final result = TradeMargin(
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      buyTotal: buyTotal,
      sellNet: sellNet,
      profit: profit,
      marginPercent: marginPercent,
      brokerFee: brokerFee,
      salesTax: salesTax,
    );

    log(
      'calculateMargin() - RESULT profit=$profit margin=$marginPercent%',
      name: 'MARKET',
    );

    return result;
  }

  /// Calculates the minimum sell price that breaks even on a buy.
  ///
  /// Returns the sell price at which [profit] equals zero, accounting
  /// for broker fees and sales tax on both sides of the trade.
  ///
  /// Throws [ArgumentError] for invalid inputs or if combined deductions
  /// make a break-even price impossible.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateBuyPrice(buyPrice);
    _validatePercent(brokerFeePercent, 'brokerFeePercent');
    _validatePercent(salesTaxPercent, 'salesTaxPercent');
    _validateDeductions(brokerFeePercent, salesTaxPercent);

    log(
      'breakEvenSellPrice() - START buy=$buyPrice '
      'brokerFee=$brokerFeePercent% tax=$salesTaxPercent%',
      name: 'MARKET',
    );

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final result =
        buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100);

    log('breakEvenSellPrice() - RESULT breakEven=$result', name: 'MARKET');

    return result;
  }

  /// Validates that [buyPrice] is a finite positive value.
  static void _validateBuyPrice(double buyPrice) {
    if (!buyPrice.isFinite || buyPrice <= 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'Expected a finite value greater than 0 for margin calculation',
      );
    }
  }

  /// Validates that [sellPrice] is a finite positive value.
  static void _validateSellPrice(double sellPrice) {
    if (!sellPrice.isFinite || sellPrice <= 0) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'Expected a finite value greater than 0 for margin calculation',
      );
    }
  }

  /// Validates that a fee/tax percentage is finite and non-negative.
  static void _validatePercent(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'Expected a finite percentage greater than or equal to 0',
      );
    }
  }

  /// Validates that combined selling deductions are strictly less than 100%.
  static void _validateDeductions(
    double brokerFeePercent,
    double salesTaxPercent,
  ) {
    if (brokerFeePercent + salesTaxPercent >= 100) {
      throw ArgumentError(
        'Expected brokerFeePercent + salesTaxPercent to be less than 100, '
        'got ${brokerFeePercent + salesTaxPercent}',
      );
    }
  }
}
