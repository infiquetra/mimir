/// Immutable result of a trade margin calculation.
///
/// Carries the original prices, all derived totals, and a convenience
/// [isProfitable] getter. Constructed exclusively by
/// [TradeCalculator.calculateMargin].
class TradeMargin {
  /// Price at which the item was purchased.
  final double buyPrice;

  /// Price at which the item will be sold.
  final double sellPrice;

  /// Total buy-side cost including broker fee: `buyPrice * (1 + brokerFeePercent/100)`.
  final double buyTotal;

  /// Net proceeds from the sale after broker fee and sales tax:
  /// `sellPrice * (1 - brokerFeePercent/100 - salesTaxPercent/100)`.
  final double sellNet;

  /// Profit (or loss): `sellNet - buyTotal`. Negative means a loss.
  final double profit;

  /// Profit as a percentage of [buyTotal]: `(profit / buyTotal) * 100`.
  final double marginPercent;

  /// Total broker fee for both sides:
  /// `buyPrice * brokerFeePercent/100 + sellPrice * brokerFeePercent/100`.
  final double brokerFee;

  /// Sales tax on the sell side: `sellPrice * salesTaxPercent/100`.
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

  /// Whether the trade yields a positive profit.
  bool get isProfitable => profit > 0;
}

/// Static calculator for market trade margins and break-even prices.
///
/// All methods are pure functions — no side effects, no state.
/// Follows the EVE Online market spec for broker fee and sales tax calculations.
class TradeCalculator {
  const TradeCalculator._();

  /// Computes the full [TradeMargin] for a buy-sell trade.
  ///
  /// [buyPrice] and [sellPrice] must be positive.
  /// [brokerFeePercent] and [salesTaxPercent] must be non-negative and their
  /// sum must be below 100 (otherwise the sell-side multiplier would be ≤ 0).
  ///
  /// Uses default EVE Online rates: broker fee 1%, sales tax 2%.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateInputs(
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
    final profit = sellNet - buyTotal;
    final marginPercent = (profit / buyTotal) * 100;
    final brokerFee =
        buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

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

  /// Returns the minimum sell price at which profit is exactly zero.
  ///
  /// This is the break-even point: selling at this price yields neither profit
  /// nor loss after all fees and taxes are deducted.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateInputs(
      buyPrice: buyPrice,
      sellPrice: null,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    return buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
  }

  /// Validates shared input constraints for [calculateMargin] and
  /// [breakEvenSellPrice].
  ///
  /// [sellPrice] is nullable because [breakEvenSellPrice] does not take one.
  static void _validateInputs({
    required double buyPrice,
    required double? sellPrice,
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    if (!buyPrice.isFinite || buyPrice <= 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'expected a positive finite buy price, got $buyPrice',
      );
    }
    if (sellPrice != null && (!sellPrice.isFinite || sellPrice <= 0)) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'expected a positive finite sell price, got $sellPrice',
      );
    }
    if (!brokerFeePercent.isFinite || brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'expected a non-negative finite broker fee percent, got $brokerFeePercent',
      );
    }
    if (!salesTaxPercent.isFinite || salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'expected a non-negative finite sales tax percent, got $salesTaxPercent',
      );
    }
    final totalFeePercent = brokerFeePercent + salesTaxPercent;
    if (totalFeePercent >= 100) {
      throw ArgumentError.value(
        totalFeePercent,
        'totalFeePercent',
        'expected broker fee plus sales tax below 100%, got $totalFeePercent%',
      );
    }
  }
}
