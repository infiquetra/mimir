/// Market margin calculator for trade profit analysis.
///
/// Rates are expressed as decimals (e.g. 0.05 means 5%).
library;

/// Immutable input for a margin calculation.
///
/// Fee and tax rates are expressed as decimals, so 0.05 means 5%.
class MarginCalculationInput {
  final double buyPrice;
  final double sellPrice;
  final int quantity;
  final double brokerFeeRate;
  final double salesTaxRate;

  const MarginCalculationInput({
    required this.buyPrice,
    required this.sellPrice,
    this.quantity = 1,
    this.brokerFeeRate = 0,
    this.salesTaxRate = 0,
  });
}

/// Immutable result of a margin calculation.
class MarginCalculationResult {
  final double totalCost;
  final double grossRevenue;
  final double brokerFees;
  final double salesTax;
  final double netRevenue;
  final double profit;
  final double profitPerUnit;
  final double marginPercent;
  final double returnOnInvestmentPercent;
  final double breakEvenSellPrice;
  final bool isProfitable;

  const MarginCalculationResult({
    required this.totalCost,
    required this.grossRevenue,
    required this.brokerFees,
    required this.salesTax,
    required this.netRevenue,
    required this.profit,
    required this.profitPerUnit,
    required this.marginPercent,
    required this.returnOnInvestmentPercent,
    required this.breakEvenSellPrice,
    required this.isProfitable,
  });
}

/// Calculates margin details for a buy/sell trade.
///
/// Returns a [MarginCalculationResult] containing total cost, revenue,
/// fees, profit, margin percentage, ROI, break-even price, and
/// profitability flag.
///
/// Throws [ArgumentError] if any input is invalid.
MarginCalculationResult calculateMargin(MarginCalculationInput input) {
  _validate(input);

  final totalCost = input.buyPrice * input.quantity;
  final grossRevenue = input.sellPrice * input.quantity;
  final brokerFees = grossRevenue * input.brokerFeeRate;
  final salesTax = grossRevenue * input.salesTaxRate;
  final netRevenue = grossRevenue - brokerFees - salesTax;
  final profit = netRevenue - totalCost;
  final profitPerUnit = profit / input.quantity;
  final marginPercent =
      grossRevenue == 0 ? 0.0 : (profit / grossRevenue) * 100;
  final returnOnInvestmentPercent = (profit / totalCost) * 100;
  final breakEvenSellPrice =
      input.buyPrice / (1 - input.brokerFeeRate - input.salesTaxRate);
  // Use a tiny epsilon to avoid floating-point drift classifying
  // mathematically-zero profit as profitable.
  final isProfitable = profit > 1e-9;

  return MarginCalculationResult(
    totalCost: totalCost,
    grossRevenue: grossRevenue,
    brokerFees: brokerFees,
    salesTax: salesTax,
    netRevenue: netRevenue,
    profit: profit,
    profitPerUnit: profitPerUnit,
    marginPercent: marginPercent,
    returnOnInvestmentPercent: returnOnInvestmentPercent,
    breakEvenSellPrice: breakEvenSellPrice,
    isProfitable: isProfitable,
  );
}

void _validate(MarginCalculationInput input) {
  if (input.buyPrice <= 0) {
    throw ArgumentError.value(
      input.buyPrice,
      'buyPrice',
      'Expected a positive value greater than 0',
    );
  }

  if (input.sellPrice < 0) {
    throw ArgumentError.value(
      input.sellPrice,
      'sellPrice',
      'Expected a non-negative value',
    );
  }

  if (input.quantity <= 0) {
    throw ArgumentError.value(
      input.quantity,
      'quantity',
      'Expected a positive integer greater than 0',
    );
  }

  if (input.brokerFeeRate < 0 || input.brokerFeeRate >= 1) {
    throw ArgumentError.value(
      input.brokerFeeRate,
      'brokerFeeRate',
      'Expected a value in the range [0, 1)',
    );
  }

  if (input.salesTaxRate < 0 || input.salesTaxRate >= 1) {
    throw ArgumentError.value(
      input.salesTaxRate,
      'salesTaxRate',
      'Expected a value in the range [0, 1)',
    );
  }

  if (input.brokerFeeRate + input.salesTaxRate >= 1) {
    throw ArgumentError.value(
      input.brokerFeeRate + input.salesTaxRate,
      'brokerFeeRate + salesTaxRate',
      'Combined fee and tax rates must be less than 1',
    );
  }
}
