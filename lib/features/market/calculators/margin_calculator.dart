/// Immutable margin calculation utilities for the Market feature.
///
/// Implements the mimir-blueprint Market Module Specification
/// section "Price Calculations", specifically:
///   - TradeCalculator.calculateMargin
///   - TradeCalculator.breakEvenSellPrice
///   - TradeMargin.isProfitable
library;

import 'package:flutter/foundation.dart';
import 'package:mimir/core/logging/logger.dart';

/// Immutable result for margin calculations.
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

  bool get isProfitable => profit > 0;
}

/// Immutable trade margin and break-even calculator.
///
/// All methods are static and pure — no side effects, no state.
class TradeCalculator {
  TradeCalculator._();

  /// Calculates margin analysis for a trade given buy/sell prices and fees.
  ///
  /// [buyPrice] must be greater than 0.
  /// [sellPrice] must be greater than or equal to 0.
  /// [brokerFeePercent] and [salesTaxPercent] must be >= 0.
  /// Total sell fees ([brokerFeePercent] + [salesTaxPercent]) must be < 100.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateBuyPrice(buyPrice);
    _validateSellPrice(sellPrice);
    _validateFees(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
    final profit = sellNet - buyTotal;
    final marginPercent = (profit / buyTotal) * 100;
    final brokerFee =
        buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    if (kDebugMode) {
      Log.d(
          'MARKET',
          'calculateMargin: buy=$buyPrice sell=$sellPrice '
              'profit=${profit.toStringAsFixed(2)} '
              'margin=${marginPercent.toStringAsFixed(2)}%');
    }

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

  /// Calculates the minimum sell price needed to break even (profit = 0).
  ///
  /// [buyPrice] must be greater than 0.
  /// [brokerFeePercent] and [salesTaxPercent] must be >= 0 and sum < 100.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateBuyPrice(buyPrice);
    _validateFees(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final result =
        buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100);

    if (kDebugMode) {
      Log.d('MARKET',
          'breakEvenSellPrice: buy=$buyPrice => ${result.toStringAsFixed(2)}');
    }

    return result;
  }

  // --- Private validators ---

  static void _validateBuyPrice(double buyPrice) {
    if (buyPrice <= 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'must be greater than 0 to calculate trade margin',
      );
    }
  }

  static void _validateSellPrice(double sellPrice) {
    if (sellPrice < 0) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'must be greater than or equal to 0',
      );
    }
  }

  static void _validateFees(double brokerFeePercent, double salesTaxPercent) {
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'must be greater than or equal to 0',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'must be greater than or equal to 0',
      );
    }
    if (brokerFeePercent + salesTaxPercent >= 100) {
      throw ArgumentError.value(
        brokerFeePercent + salesTaxPercent,
        'totalSellFeesPercent',
        'must be less than 100',
      );
    }
  }
}
