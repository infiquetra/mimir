import 'package:mimir/core/logging/logger.dart';

class TradeCalculator {
  TradeCalculator._();

  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    Log.d(
      'MARKET',
      'calculateMargin - buyPrice: $buyPrice, sellPrice: $sellPrice, '
          'brokerFeePercent: $brokerFeePercent, salesTaxPercent: $salesTaxPercent',
    );

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

  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = 1.0,
    double salesTaxPercent = 2.0,
  }) {
    Log.d(
      'MARKET',
      'breakEvenSellPrice - buyPrice: $buyPrice, '
          'brokerFeePercent: $brokerFeePercent, salesTaxPercent: $salesTaxPercent',
    );

    _validateInputs(
      buyPrice: buyPrice,
      brokerFeePercent: brokerFeePercent,
      salesTaxPercent: salesTaxPercent,
    );

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    return buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
  }

  static void _validateInputs({
    required double buyPrice,
    double? sellPrice,
    required double brokerFeePercent,
    required double salesTaxPercent,
  }) {
    if (!buyPrice.isFinite || buyPrice <= 0) {
      throw ArgumentError.value(
        buyPrice,
        'buyPrice',
        'Expected a finite value greater than 0, got $buyPrice',
      );
    }

    if (sellPrice != null) {
      if (!sellPrice.isFinite || sellPrice < 0) {
        throw ArgumentError.value(
          sellPrice,
          'sellPrice',
          'Expected a finite value greater than or equal to 0, got $sellPrice',
        );
      }
    }

    if (!brokerFeePercent.isFinite || brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'Expected a finite non-negative value, got $brokerFeePercent',
      );
    }

    if (!salesTaxPercent.isFinite || salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'Expected a finite non-negative value, got $salesTaxPercent',
      );
    }

    final sellDeductionPercent = brokerFeePercent + salesTaxPercent;
    if (sellDeductionPercent >= 100) {
      throw ArgumentError.value(
        sellDeductionPercent,
        'brokerFeePercent + salesTaxPercent',
        'Expected combined sell-side fees below 100%, got $sellDeductionPercent',
      );
    }
  }
}

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
