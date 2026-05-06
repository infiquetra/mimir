/// Margin calculator for EVE Online trade analysis.
///
/// Provides static utility methods for calculating trade margins and
/// break-even sell prices, plus an immutable [TradeMargin] value object
/// carrying the computed results.
///
/// Spec sections addressed: Price Calculations.
library margin_calculator;

/// Immutable result of a trade margin calculation.
///
/// All fields are in ISK except [marginPercent] (a percentage).
final class TradeMargin {
  /// The ISK price paid to buy the item.
  final double buyPrice;

  /// The ISK price at which the item is sold.
  final double sellPrice;

  /// Total buy-side cost including the buy broker fee.
  final double buyTotal;

  /// Net ISK received from the sale after broker fee and sales tax.
  final double sellNet;

  /// Net profit (sellNet - buyTotal). Negative when the trade loses money.
  final double profit;

  /// Profit as a percentage of buyTotal.
  final double marginPercent;

  /// Total broker fee paid on buy and sell sides.
  final double brokerFee;

  /// Sales tax paid on the sell side.
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

  /// Whether this trade turns a profit (profit > 0).
  bool get isProfitable => profit > 0;
}

/// Static calculator for EVE Online trade margins.
///
/// Uses the standard NPC station formulas with configurable broker fee
/// and sales tax percentages.  The default values match the NPC station
/// defaults: 1% broker fee, 2% sales tax.
final class TradeCalculator {
  const TradeCalculator._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Computes the full trade margin for a buy-and-sell round-trip.
  ///
  /// [brokerFeePercent] and [salesTaxPercent] default to 1% and 2%
  /// respectively (NPC station defaults).  Both are applied on the sell
  /// side; only the broker fee is also applied on the buy side.
  ///
  /// Throws [ArgumentError] when any input is non-finite, non-positive
  /// (prices), negative (percentages), or the combined sell-side fee is
  /// ≥ 100%.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePrice(buyPrice, 'buyPrice');
    _validatePrice(sellPrice, 'sellPrice');
    _validateFeePercent(brokerFeePercent, 'brokerFeePercent');
    _validateFeePercent(salesTaxPercent, 'salesTaxPercent');
    _validateCombinedFees(brokerFeePercent, salesTaxPercent);

    final brokerFeeRate = brokerFeePercent / 100;
    final salesTaxRate = salesTaxPercent / 100;

    final buyTotal = buyPrice * (1 + brokerFeeRate);
    final sellNet = sellPrice * (1 - brokerFeeRate - salesTaxRate);
    final profit = sellNet - buyTotal;
    final marginPercent = (profit / buyTotal) * 100;
    final brokerFee = (buyPrice * brokerFeeRate) + (sellPrice * brokerFeeRate);
    final salesTax = sellPrice * salesTaxRate;

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

  /// Computes the sell price at which profit is exactly zero.
  ///
  /// Returns the ISK price that, after broker fee and sales tax, nets
  /// exactly the buy-side total.  Same defaults and validation as
  /// [calculateMargin].
  ///
  /// Throws [ArgumentError] when inputs are non-finite, non-positive
  /// ([buyPrice]), negative ([brokerFeePercent], [salesTaxPercent]), or
  /// the combined sell-side fee is ≥ 100%.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePrice(buyPrice, 'buyPrice');
    _validateFeePercent(brokerFeePercent, 'brokerFeePercent');
    _validateFeePercent(salesTaxPercent, 'salesTaxPercent');
    _validateCombinedFees(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellSideRate = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    return buyTotal / sellSideRate;
  }

  // ---------------------------------------------------------------------------
  // Validation helpers
  // ---------------------------------------------------------------------------

  static void _validatePrice(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        name,
        'expected a finite number, got $value',
      );
    }
    if (value <= 0) {
      throw ArgumentError.value(
        value,
        name,
        'expected a positive ISK price, got $value',
      );
    }
  }

  static void _validateFeePercent(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        name,
        'expected a finite number, got $value',
      );
    }
    if (value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'expected a non-negative percentage, got $value',
      );
    }
  }

  static void _validateCombinedFees(
    double brokerFeePercent,
    double salesTaxPercent,
  ) {
    final totalFeePercent = brokerFeePercent + salesTaxPercent;
    if (totalFeePercent >= 100) {
      throw ArgumentError.value(
        totalFeePercent,
        'totalFeePercent',
        'expected combined sell-side fees below 100%, got $totalFeePercent',
      );
    }
  }
}
