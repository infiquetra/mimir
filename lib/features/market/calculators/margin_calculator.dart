/// Immutable result of a margin trade calculation.
///
/// All amounts are in ISK except [marginPercent] which is a percentage value.
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

  /// Whether the trade is profitable (profit > 0).
  bool get isProfitable => profit > 0;
}

/// Margin calculator for EVE Online market trades.
///
/// Computes trade margin, profit, and break-even sell price using
/// broker fees and sales tax as configurable percentages.
class MarginCalculator {
  const MarginCalculator._();

  // ── Validation helpers ────────────────────────────────────────────────

  static void _validatePositive(String name, double value) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(
        value,
        name,
        'must be a finite positive ISK amount',
      );
    }
  }

  static void _validatePercent(String name, double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        name,
        'must be a finite percentage greater than or equal to 0',
      );
    }
  }

  static void _validateSellDeductions(
    double brokerFeePercent,
    double salesTaxPercent,
  ) {
    final sum = brokerFeePercent + salesTaxPercent;
    if (sum >= 100) {
      throw ArgumentError.value(
        sum,
        'brokerFeePercent + salesTaxPercent',
        'must be less than 100 so sell net and break-even price are defined',
      );
    }
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Calculates the complete margin analysis for a trade.
  ///
  /// [buyPrice] and [sellPrice] are the ISK amounts per unit.
  /// [brokerFeePercent] defaults to 1.0% (applied to both buy and sell).
  /// [salesTaxPercent] defaults to 2.0% (applied to sell price only).
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePositive('buyPrice', buyPrice);
    _validatePositive('sellPrice', sellPrice);
    _validatePercent('brokerFeePercent', brokerFeePercent);
    _validatePercent('salesTaxPercent', salesTaxPercent);
    _validateSellDeductions(brokerFeePercent, salesTaxPercent);

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

  /// Returns the sell price at which profit is exactly zero.
  ///
  /// The formula accounts for the same broker fee and sales tax
  /// percentages as [calculateMargin].
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validatePositive('buyPrice', buyPrice);
    _validatePercent('brokerFeePercent', brokerFeePercent);
    _validatePercent('salesTaxPercent', salesTaxPercent);
    _validateSellDeductions(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    return buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
  }
}

/// Compatibility facade that forwards to [MarginCalculator].
///
/// Preserves the method names from the original specification's
/// `TradeCalculator` class while keeping all formula logic in
/// [MarginCalculator].
class TradeCalculator {
  const TradeCalculator._();

  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    return MarginCalculator.calculateMargin(
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );
  }

  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    return MarginCalculator.breakEvenSellPrice(
      buyPrice: buyPrice,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );
  }
}
