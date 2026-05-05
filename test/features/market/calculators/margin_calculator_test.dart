import 'package:flutter_test/flutter_test.dart';

import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('calculates profitable station trade margin with default fees', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: 150,
      );

      expect(margin.buyTotal, closeTo(101.0, 0.001));
      expect(margin.sellNet, closeTo(145.5, 0.001));
      expect(margin.profit, closeTo(44.5, 0.001));
      expect(margin.marginPercent, closeTo(44.05940594059406, 0.001));
      expect(margin.brokerFee, closeTo(2.5, 0.001));
      expect(margin.salesTax, closeTo(3.0, 0.001));
      expect(margin.isProfitable, isTrue);
    });

    test('calculates unprofitable trade after fees', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: 100,
      );

      expect(margin.profit, closeTo(-4.0, 0.001));
      expect(margin.marginPercent, closeTo(-3.9603960396039604, 0.001));
      expect(margin.isProfitable, isFalse);
    });

    test('uses custom broker fee and sales tax percentages', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: 150,
        brokerFeePercent: 0.5,
        salesTaxPercent: 1.5,
      );

      expect(margin.buyTotal, closeTo(100.5, 0.001));
      expect(margin.sellNet, closeTo(147.0, 0.001));
      expect(margin.profit, closeTo(46.5, 0.001));
      expect(margin.marginPercent, closeTo(46.26865671641794, 0.001));
      expect(margin.brokerFee, closeTo(1.25, 0.001));
      expect(margin.salesTax, closeTo(2.25, 0.001));
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates break-even sell price with default fees', () {
      final breakEven = TradeCalculator.breakEvenSellPrice(buyPrice: 100);

      expect(breakEven, closeTo(104.12371134020619, 0.001));
    });

    test('calculates break-even sell price with custom fees', () {
      final breakEven = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100,
        brokerFeePercent: 0.5,
        salesTaxPercent: 1.5,
      );

      expect(breakEven, closeTo(102.55102040816325, 0.001));
    });
  });

  group('TradeCalculator validation', () {
    test('throws ArgumentError when buy price is not positive', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 0, sellPrice: 100),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: -1, sellPrice: 100),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when sell price is negative', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 100, sellPrice: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when fee percentages are negative', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          salesTaxPercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when combined fees are 100 percent or more', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: 80,
          salesTaxPercent: 20,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: 80,
          salesTaxPercent: 20,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
