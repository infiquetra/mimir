/// Pure-Dart trade margin calculator.
///
/// All math follows EVE Online's fee structure:
/// - Broker fee is paid on both buy and sell orders.
/// - Sales tax is paid only on sell orders.
class TradeCalculator {
  /// Calculate profit margin for station trading.
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    final brokerFeeRate = brokerFeePercent / 100;
    final salesTaxRate = salesTaxPercent / 100;

    final buyTotal = buyPrice * (1 + brokerFeeRate);
    final sellNet = sellPrice * (1 - brokerFeeRate - salesTaxRate);
    final profit = sellNet - buyTotal;
    final marginPercent = buyTotal > 0 ? (profit / buyTotal) * 100 : 0.0;

    return TradeMargin(
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      buyTotal: buyTotal,
      sellNet: sellNet,
      profit: profit,
      marginPercent: marginPercent,
      brokerFee: buyPrice * brokerFeeRate + sellPrice * brokerFeeRate,
      salesTax: sellPrice * salesTaxRate,
    );
  }

  /// Calculate the break-even sell price given a buy price.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    // sellNet = sellPrice * (1 - brokerFee - salesTax) = buyTotal
    // sellPrice = buyTotal / (1 - brokerFee - salesTax)
    final denominator = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    if (denominator <= 0) return double.infinity;
    return buyTotal / denominator;
  }
}

/// Result of a trade margin calculation.
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
