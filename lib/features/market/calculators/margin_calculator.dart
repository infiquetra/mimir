/// Immutable data class representing the result of a margin calculation.
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

/// Calculator for trading margins, fees, and break-even prices.
class TradeCalculator {
  TradeCalculator._();

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

    final brokerFeeBuy = buyPrice * brokerFeePercent / 100;
    final brokerFeeSell = sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    final buyTotal = buyPrice + brokerFeeBuy;
    final sellNet = sellPrice - brokerFeeSell - salesTax;
    final profit = sellNet - buyTotal;
    final marginPercent = (profit / buyTotal) * 100;

    return TradeMargin(
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      buyTotal: buyTotal,
      sellNet: sellNet,
      profit: profit,
      marginPercent: marginPercent,
      brokerFee: brokerFeeBuy + brokerFeeSell,
      salesTax: salesTax,
    );
  }

  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    _validateInputs(
      buyPrice: buyPrice,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellFeeFactor = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;

    return buyTotal / sellFeeFactor;
  }

  static void _validateInputs({
    required double buyPrice,
    double? sellPrice,
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    if (buyPrice <= 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'must be positive',
      );
    }

    if (sellPrice != null && sellPrice <= 0) {
      throw ArgumentError.value(
        sellPrice,
        'sellPrice',
        'must be positive',
      );
    }

    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'must not be negative',
      );
    }

    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'must not be negative',
      );
    }

    final sellFeeFactor = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    if (sellFeeFactor <= 0) {
      throw ArgumentError.value(
        brokerFeePercent + salesTaxPercent,
        'combined fees and taxes',
        'must be less than 100%',
      );
    }
  }
}
