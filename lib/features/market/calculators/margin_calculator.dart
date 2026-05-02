/// Immutable result of a margin calculation for EVE Online station trading.
///
/// Returned by [TradeCalculator.calculateMargin].
final class TradeMargin {
  /// The original buy price per unit (ISK).
  final double buyPrice;

  /// The original sell price per unit (ISK).
  final double sellPrice;

  /// Total cost to buy including broker fee: `buyPrice + buyBrokerFee`.
  final double buyTotal;

  /// Net revenue from selling after broker fee and sales tax:
  /// `sellPrice - sellBrokerFee - salesTax`.
  final double sellNet;

  /// Profit or loss: `sellNet - buyTotal`. Positive is profit, negative
  /// is loss, zero is break-even (ignoring rounding).
  final double profit;

  /// Profit as a percentage of buy total: `(profit / buyTotal) * 100`.
  final double marginPercent;

  /// Total broker fees paid on both sides of the trade:
  /// `buyBrokerFee + sellBrokerFee`.
  final double brokerFee;

  /// Sales tax paid: `sellPrice * salesTaxPercent / 100`.
  final double salesTax;

  /// Whether the trade is profitable (profit greater than zero).
  bool get isProfitable => profit > 0;

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
}

/// Pure-Dart margin calculator for EVE Online station trading.
///
/// Provides static functions for profit/margin analysis and break-even
/// pricing. All methods are pure functions — no state, no dependencies,
/// no side effects.
///
/// See the Market module spec, **Price Calculations** section.
final class TradeCalculator {
  const TradeCalculator._();

  /// Calculates the margin (profit/loss, fees, taxes) for a trade.
  ///
  /// All percentage arguments default to EVE Online NPC station rates:
  /// - [brokerFeePercent]: Broker fee as percentage (default 1.0%).
  /// - [salesTaxPercent]: Sales tax as percentage (default 2.0%).
  ///
  /// Throws [ArgumentError] if any input is invalid:
  /// - [buyPrice] must be > 0.
  /// - [sellPrice] must be >= 0.
  /// - [brokerFeePercent] and [salesTaxPercent] must be >= 0 and their
  ///   sum must be < 100.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateTradeInputs(
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

    final buyBrokerFee = buyPrice * brokerFeePercent / 100;
    final sellBrokerFee = sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    final buyTotal = buyPrice + buyBrokerFee;
    final sellNet = sellPrice - sellBrokerFee - salesTax;
    final profit = sellNet - buyTotal;
    final marginPercent = (profit / buyTotal) * 100;
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

  /// Calculates the minimum sell price needed to break even.
  ///
  /// Uses the formula: `buyTotal / (1 - brokerFeePercent/100 -
  /// salesTaxPercent/100)` where `buyTotal = buyPrice * (1 +
  /// brokerFeePercent / 100)`.
  ///
  /// Throws [ArgumentError] under the same conditions as
  /// [calculateMargin] for buyPrice and percentage arguments.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateBreakEvenInputs(
      buyPrice: buyPrice,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final feeRate = brokerFeePercent / 100 + salesTaxPercent / 100;

    return buyTotal / (1 - feeRate);
  }

  /// Validates inputs for [calculateMargin].
  static void _validateTradeInputs({
    required double buyPrice,
    required double sellPrice,
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    if (buyPrice <= 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'must be greater than 0, got $buyPrice',
      );
    }
    if (sellPrice < 0) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'must be non-negative, got $sellPrice',
      );
    }
    _validateFeeInputs(
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );
  }

  /// Validates inputs for [breakEvenSellPrice].
  static void _validateBreakEvenInputs({
    required double buyPrice,
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    if (buyPrice <= 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'must be greater than 0, got $buyPrice',
      );
    }
    _validateFeeInputs(
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );
  }

  /// Validates broker fee and sales tax percentage inputs.
  static void _validateFeeInputs({
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'must be non-negative, got $brokerFeePercent',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'must be non-negative, got $salesTaxPercent',
      );
    }
    if (brokerFeePercent + salesTaxPercent >= 100) {
      throw ArgumentError.value(
        brokerFeePercent + salesTaxPercent,
        'brokerFeePercent + salesTaxPercent',
        'sum must be less than 100, got ${brokerFeePercent + salesTaxPercent}',
      );
    }
  }
}
