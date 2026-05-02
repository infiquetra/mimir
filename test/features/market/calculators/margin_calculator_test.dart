import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

/// Shorter alias for readability.
Matcher closeToDouble(double expected) => closeTo(expected, 0.000001);

void main() {
  group('MarginCalculator.calculateMargin', () {
    test('applies default broker fee and sales tax', () {
      const buyPrice = 100.0;
      const sellPrice = 150.0;

      final result = MarginCalculator.calculateMargin(
        buyPrice: buyPrice,
        sellPrice: sellPrice,
      );

      expect(result.buyPrice, buyPrice);
      expect(result.sellPrice, sellPrice);
      expect(result.buyTotal, closeToDouble(101.0));
      expect(result.sellNet, closeToDouble(145.5));
      expect(result.profit, closeToDouble(44.5));
      expect(result.marginPercent, closeToDouble(44.05940594059406));
      expect(result.brokerFee, closeToDouble(2.5));
      expect(result.salesTax, closeToDouble(3.0));
      expect(result.isProfitable, isTrue);
    });

    test('reports unprofitable trade', () {
      const buyPrice = 100.0;
      const sellPrice = 90.0;

      final result = MarginCalculator.calculateMargin(
        buyPrice: buyPrice,
        sellPrice: sellPrice,
      );

      expect(result.profit, lessThan(0));
      expect(result.marginPercent, lessThan(0));
      expect(result.isProfitable, isFalse);
    });

    test('uses custom fee percentages', () {
      const buyPrice = 200.0;
      const sellPrice = 260.0;
      const brokerFeePercent = 2.5;
      const salesTaxPercent = 4.0;

      final result = MarginCalculator.calculateMargin(
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        brokerFeePercent: brokerFeePercent,
        salesTaxPercent: salesTaxPercent,
      );

      expect(result.buyTotal, closeToDouble(205.0));
      expect(result.sellNet, closeToDouble(243.1));
      expect(result.profit, closeToDouble(38.1));
      expect(result.brokerFee, closeToDouble(11.5));
      expect(result.salesTax, closeToDouble(10.4));
      expect(result.marginPercent, closeToDouble(18.585365853658537));
      expect(result.isProfitable, isTrue);
    });
  });

  group('MarginCalculator.breakEvenSellPrice', () {
    test('returns sell price that makes profit zero with default fees', () {
      const buyPrice = 100.0;

      final breakEven = MarginCalculator.breakEvenSellPrice(buyPrice: buyPrice);

      expect(breakEven, closeToDouble(104.12371134020619));

      // Verify that using this sell price yields zero profit.
      final margin = MarginCalculator.calculateMargin(
        buyPrice: buyPrice,
        sellPrice: breakEven,
      );
      expect(margin.profit, closeToDouble(0.0));
    });

    test('uses custom fee percentages', () {
      const buyPrice = 200.0;
      const brokerFeePercent = 2.5;
      const salesTaxPercent = 4.0;

      final breakEven = MarginCalculator.breakEvenSellPrice(
        buyPrice: buyPrice,
        brokerFeePercent: brokerFeePercent,
        salesTaxPercent: salesTaxPercent,
      );

      expect(breakEven, closeToDouble(219.25133689839572));

      // Verify round-trip: using break-even price yields ~zero profit.
      final margin = MarginCalculator.calculateMargin(
        buyPrice: buyPrice,
        sellPrice: breakEven,
        brokerFeePercent: brokerFeePercent,
        salesTaxPercent: salesTaxPercent,
      );
      expect(margin.profit, closeToDouble(0.0));
    });
  });

  group('validation', () {
    test('calculateMargin rejects non-positive prices', () {
      expect(
        () => MarginCalculator.calculateMargin(buyPrice: 0.0, sellPrice: 100.0),
        throwsArgumentError,
      );

      expect(
        () =>
            MarginCalculator.calculateMargin(buyPrice: 100.0, sellPrice: -1.0),
        throwsArgumentError,
      );
    });

    test('calculators reject invalid fee percentages', () {
      // Negative brokerFeePercent.
      expect(
        () => MarginCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 150.0,
          brokerFeePercent: -1.0,
        ),
        throwsArgumentError,
      );

      // brokerFeePercent + salesTaxPercent >= 100 for calculateMargin.
      expect(
        () => MarginCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 150.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );

      // brokerFeePercent + salesTaxPercent >= 100 for breakEvenSellPrice.
      expect(
        () => MarginCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
    });

    test('calculators reject non-finite inputs', () {
      // NaN price.
      expect(
        () => MarginCalculator.calculateMargin(
          buyPrice: double.nan,
          sellPrice: 100.0,
        ),
        throwsArgumentError,
      );

      // Infinity price.
      expect(
        () => MarginCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: double.infinity,
        ),
        throwsArgumentError,
      );

      // NaN fee percent.
      expect(
        () => MarginCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: double.nan,
        ),
        throwsArgumentError,
      );

      // Infinity fee percent.
      expect(
        () => MarginCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          salesTaxPercent: double.infinity,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeCalculator facade', () {
    test('matches MarginCalculator results', () {
      const buyPrice = 100.0;
      const sellPrice = 150.0;
      const brokerFeePercent = 1.5;
      const salesTaxPercent = 3.0;

      final marginMargin = MarginCalculator.calculateMargin(
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        brokerFeePercent: brokerFeePercent,
        salesTaxPercent: salesTaxPercent,
      );

      final tradeMargin = TradeCalculator.calculateMargin(
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        brokerFeePercent: brokerFeePercent,
        salesTaxPercent: salesTaxPercent,
      );

      expect(tradeMargin.profit, marginMargin.profit);
      expect(tradeMargin.marginPercent, marginMargin.marginPercent);
      expect(tradeMargin.brokerFee, marginMargin.brokerFee);
      expect(tradeMargin.salesTax, marginMargin.salesTax);
      expect(tradeMargin.buyTotal, marginMargin.buyTotal);
      expect(tradeMargin.sellNet, marginMargin.sellNet);
      expect(tradeMargin.isProfitable, marginMargin.isProfitable);

      final marginBreakEven = MarginCalculator.breakEvenSellPrice(
        buyPrice: buyPrice,
        brokerFeePercent: brokerFeePercent,
        salesTaxPercent: salesTaxPercent,
      );

      final tradeBreakEven = TradeCalculator.breakEvenSellPrice(
        buyPrice: buyPrice,
        brokerFeePercent: brokerFeePercent,
        salesTaxPercent: salesTaxPercent,
      );

      expect(tradeBreakEven, closeToDouble(marginBreakEven));
    });
  });
}
