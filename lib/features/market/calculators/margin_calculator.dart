/// Pure Dart margin calculator for EVE Online market trade profit/margin analysis.
///
/// Provides [calculateMargin] which computes gross costs, revenue, fees, taxes,
/// and net profit, returning a typed [MarginCalculationResult] with derived
/// percentage getters.
library;

/// Result of a margin calculation for a single trade.
///
/// All fields are immutable. Percentages returned by getters are in percentage
/// units (e.g., 20 means 20%, not 0.20). Fee rates in [calculateMargin] are
/// decimal rates (e.g., 0.05 means 5%).
class MarginCalculationResult {
  /// Buy price per unit (ISK).
  final double buyPrice;

  /// Sell price per unit (ISK).
  final double sellPrice;

  /// Number of units traded.
  final int quantity;

  /// Broker fee as a decimal rate (0–1).
  final double brokerFeeRate;

  /// Sales tax as a decimal rate (0–1).
  final double salesTaxRate;

  /// Total ISK from selling: [sellPrice] × [quantity].
  final double grossRevenue;

  /// Total ISK spent buying: [buyPrice] × [quantity].
  final double grossCost;

  /// Broker fee in ISK: [grossRevenue] × [brokerFeeRate].
  final double brokerFee;

  /// Sales tax in ISK: [grossRevenue] × [salesTaxRate].
  final double salesTax;

  /// Net profit in ISK: [grossRevenue] − [grossCost] − [brokerFee] − [salesTax].
  final double netProfit;

  const MarginCalculationResult({
    required this.buyPrice,
    required this.sellPrice,
    required this.quantity,
    required this.brokerFeeRate,
    required this.salesTaxRate,
    required this.grossRevenue,
    required this.grossCost,
    required this.brokerFee,
    required this.salesTax,
    required this.netProfit,
  });

  /// Profit margin as a percentage of gross revenue.
  ///
  /// Returns 0 when [grossRevenue] is 0 (no division by zero).
  double get profitMarginPercent =>
      grossRevenue == 0 ? 0 : (netProfit / grossRevenue) * 100;

  /// Return on investment as a percentage of gross cost.
  ///
  /// Returns 0 when [grossCost] is 0 (no division by zero).
  double get returnOnInvestmentPercent =>
      grossCost == 0 ? 0 : (netProfit / grossCost) * 100;

  /// True when [netProfit] is strictly positive.
  bool get isProfitable => netProfit > 0;
}

/// Computes the margin for an EVE Online market trade.
///
/// All fee and tax rates are decimal fractions: 0.05 means 5%. The returned
/// [MarginCalculationResult] provides percentage getters ([profitMarginPercent],
/// [returnOnInvestmentPercent]) that return values like 20 (meaning 20%).
///
/// Throws [ArgumentError] for any invalid input:
/// - [buyPrice] or [sellPrice] negative
/// - [quantity] less than 1
/// - [brokerFeeRate] or [salesTaxRate] outside [0, 1]
MarginCalculationResult calculateMargin({
  required double buyPrice,
  required double sellPrice,
  int quantity = 1,
  double brokerFeeRate = 0,
  double salesTaxRate = 0,
}) {
  if (buyPrice < 0) {
    throw ArgumentError.value(
      buyPrice,
      'buyPrice',
      'Must be greater than or equal to 0',
    );
  }
  if (sellPrice < 0) {
    throw ArgumentError.value(
      sellPrice,
      'sellPrice',
      'Must be greater than or equal to 0',
    );
  }
  if (quantity < 1) {
    throw ArgumentError.value(
      quantity,
      'quantity',
      'Must be greater than or equal to 1',
    );
  }
  if (brokerFeeRate < 0 || brokerFeeRate > 1) {
    throw ArgumentError.value(
      brokerFeeRate,
      'brokerFeeRate',
      'Must be between 0 and 1 inclusive',
    );
  }
  if (salesTaxRate < 0 || salesTaxRate > 1) {
    throw ArgumentError.value(
      salesTaxRate,
      'salesTaxRate',
      'Must be between 0 and 1 inclusive',
    );
  }

  final grossCost = buyPrice * quantity;
  final grossRevenue = sellPrice * quantity;
  final brokerFee = grossRevenue * brokerFeeRate;
  final salesTax = grossRevenue * salesTaxRate;
  final netProfit = grossRevenue - grossCost - brokerFee - salesTax;

  return MarginCalculationResult(
    buyPrice: buyPrice,
    sellPrice: sellPrice,
    quantity: quantity,
    brokerFeeRate: brokerFeeRate,
    salesTaxRate: salesTaxRate,
    grossRevenue: grossRevenue,
    grossCost: grossCost,
    brokerFee: brokerFee,
    salesTax: salesTax,
    netProfit: netProfit,
  );
}
