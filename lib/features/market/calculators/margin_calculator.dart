// Market module margin calculator.
//
// Provides [TradeCalculator] for margin and break-even price
// computations, plus the [TradeMargin] value object.

/// Immutable result of a margin calculation.
class TradeMargin {
  /// Creates a [TradeMargin].
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

  /// Original buy price.
  final double buyPrice;

  /// Original sell price.
  final double sellPrice;

  /// Total cost to buy (price + broker fee).
  final double buyTotal;

  /// Net proceeds from selling (price minus fees and tax).
  final double sellNet;

  /// Absolute profit in ISK.
  final double profit;

  /// Profit as a percentage of [buyTotal].
  final double marginPercent;

  /// Total broker fee for both sides of the trade.
  final double brokerFee;

  /// Sales tax on the sell price.
  final double salesTax;

  /// Whether this trade yields a positive profit.
  bool get isProfitable => profit > 0;
}

/// Stateless helper for trade calculations.
class TradeCalculator {
  TradeCalculator._();

  /// Validates numeric inputs common to both methods.
  static void _validateCommon({
    required double buyPrice,
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    if (!buyPrice.isFinite) {
      throw ArgumentError.value(buyPrice, 'buyPrice', 'must be finite');
    }
    if (buyPrice < 0) {
      throw ArgumentError.value(buyPrice, 'buyPrice', 'must not be negative');
    }
    if (!brokerFeePercent.isFinite) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'must be finite',
      );
    }
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'must not be negative',
      );
    }
    if (!salesTaxPercent.isFinite) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'must be finite',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'must not be negative',
      );
    }
    if ((brokerFeePercent + salesTaxPercent) >= 100) {
      throw ArgumentError(
        'Combined sell-side fees must be below 100% '
        '(got brokerFeePercent=$brokerFeePercent, '
        'salesTaxPercent=$salesTaxPercent)',
      );
    }
  }

  /// Calculates the margin for a buy-and-sell trade.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateCommon(
      buyPrice: buyPrice,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

    if (!sellPrice.isFinite) {
      throw ArgumentError.value(sellPrice, 'sellPrice', 'must be finite');
    }
    if (sellPrice < 0) {
      throw ArgumentError.value(sellPrice, 'sellPrice', 'must not be negative');
    }

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
    final profit = sellNet - buyTotal;
    final marginPercent = buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;
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

  /// Computes the break-even sell price for a given buy price and fees.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateCommon(
      buyPrice: buyPrice,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellFeeMultiplier =
        1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    return buyTotal / sellFeeMultiplier;
  }
}
