import 'package:mimir/core/logging/logger.dart';

/// Immutable result of a trade margin calculation.
///
/// All fields are [double] and final. No JSON serialization or code
/// generation is included — this is a pure value object.
class TradeMargin {
  /// Original buy price.
  final double buyPrice;

  /// Original sell price.
  final double sellPrice;

  /// Total cost to buy, including broker fee: `buyPrice * (1 + brokerFee / 100)`.
  final double buyTotal;

  /// Net proceeds from selling, after broker fee and sales tax:
  /// `sellPrice * (1 - brokerFee / 100 - salesTax / 100)`.
  final double sellNet;

  /// Profit (positive) or loss (negative): `sellNet - buyTotal`.
  final double profit;

  /// Margin as a percentage of buyTotal. Zero when buyTotal is zero.
  final double marginPercent;

  /// Total broker fee paid: `brokerFee on buy + brokerFee on sell`.
  final double brokerFee;

  /// Sales tax paid on the sell side: `sellPrice * salesTax / 100`.
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

  /// Whether this trade is profitable (profit > 0).
  bool get isProfitable => profit > 0;
}

/// Pure calculator for EVE Online trade margins.
///
/// Static methods accept input values and return either a [TradeMargin]
/// or a break-even sell price.  All public methods validate inputs and
/// throw [ArgumentError] with context when values are invalid.
class TradeCalculator {
  static const double _defaultBrokerFeePercent = 1.0;
  static const double _defaultSalesTaxPercent = 2.0;
  static const String _tag = 'MARKET';

  // -----------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------

  /// Calculate the trade margin for a buy/sell pair.
  ///
  /// [buyPrice] and [sellPrice] must be >= 0.
  /// [brokerFeePercent] and [salesTaxPercent] must be >= 0 and,
  /// together, must be < 100 (otherwise sell net proceeds would be
  /// zero or negative).
  ///
  /// Defaults: [brokerFeePercent] = 1.0, [salesTaxPercent] = 2.0
  /// (EVE Online standard NPC station rates).
  static TradeMargin calculateMargin({
    required double buyPrice,
    required double sellPrice,
    double brokerFeePercent = _defaultBrokerFeePercent,
    double salesTaxPercent = _defaultSalesTaxPercent,
  }) {
    _validatePrice('buyPrice', buyPrice, allowZero: true);
    _validatePrice('sellPrice', sellPrice, allowZero: true);
    _validateFeePercentages(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final sellNet =
        sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100);
    final profit = sellNet - buyTotal;
    final marginPercent = buyTotal == 0 ? 0.0 : (profit / buyTotal) * 100;
    final brokerFee =
        buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100;
    final salesTax = sellPrice * salesTaxPercent / 100;

    final result = TradeMargin(
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      buyTotal: buyTotal,
      sellNet: sellNet,
      profit: profit,
      marginPercent: marginPercent,
      brokerFee: brokerFee,
      salesTax: salesTax,
    );

    Log.d(
      _tag,
      'Margin calc: buy=$buyPrice sell=$sellPrice '
      'bf=$brokerFeePercent% st=$salesTaxPercent% '
      'profit=$profit margin=$marginPercent%',
    );

    return result;
  }

  /// Calculate the break-even sell price for a given buy price and fee
  /// rates so that profit = 0.
  ///
  /// [buyPrice] must be >= 0.
  /// [brokerFeePercent] and [salesTaxPercent] must be >= 0 and,
  /// together, must be < 100.
  ///
  /// Defaults: [brokerFeePercent] = 1.0, [salesTaxPercent] = 2.0.
  static double breakEvenSellPrice({
    required double buyPrice,
    double brokerFeePercent = _defaultBrokerFeePercent,
    double salesTaxPercent = _defaultSalesTaxPercent,
  }) {
    _validatePrice('buyPrice', buyPrice, allowZero: true);
    _validateFeePercentages(brokerFeePercent, salesTaxPercent);

    final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
    final denominator = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;
    final breakEven = buyTotal / denominator;

    Log.d(
      _tag,
      'Break-even: buy=$buyPrice bf=$brokerFeePercent% '
      'st=$salesTaxPercent% → $breakEven',
    );

    return breakEven;
  }

  // -----------------------------------------------------------------
  // Validation helpers
  // -----------------------------------------------------------------

  /// Validate that [value] is a finite number >= 0.
  static void _validatePrice(
    String name,
    double value, {
    required bool allowZero,
  }) {
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError.value(value, name, 'must be a finite number');
    }
    final lower = allowZero ? 0.0 : 0.0;
    if (value < lower) {
      throw ArgumentError.value(value, name, 'must be >= 0, got $value');
    }
  }

  /// Validate that fee percentages are non-negative and their sum
  /// is < 100.
  static void _validateFeePercentages(
    double brokerFeePercent,
    double salesTaxPercent,
  ) {
    if (brokerFeePercent.isNaN || brokerFeePercent.isInfinite) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'must be a finite number',
      );
    }
    if (brokerFeePercent < 0) {
      throw ArgumentError.value(
        brokerFeePercent,
        'brokerFeePercent',
        'must be >= 0, got $brokerFeePercent',
      );
    }
    if (salesTaxPercent.isNaN || salesTaxPercent.isInfinite) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'must be a finite number',
      );
    }
    if (salesTaxPercent < 0) {
      throw ArgumentError.value(
        salesTaxPercent,
        'salesTaxPercent',
        'must be >= 0, got $salesTaxPercent',
      );
    }
    if (brokerFeePercent + salesTaxPercent >= 100) {
      throw ArgumentError.value(
        brokerFeePercent + salesTaxPercent,
        'brokerFeePercent + salesTaxPercent',
        'must be < 100 (would produce zero or negative sell proceeds). '
            'brokerFeePercent=$brokerFeePercent, salesTaxPercent=$salesTaxPercent',
      );
    }
  }
}
