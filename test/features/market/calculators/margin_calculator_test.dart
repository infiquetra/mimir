import 'package:flutter_test/flutter_test.dart';

import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator', () {
    // ---------------------------------------------------------------
    // Success-path tests
    // ---------------------------------------------------------------

    test('calculates margin correctly', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1100000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(margin.buyPrice, 1000000);
      expect(margin.sellPrice, 1100000);
      expect(margin.buyTotal, 1010000);
      expect(margin.sellNet, 1067000);
      expect(margin.profit, 57000);
      expect(margin.marginPercent, closeTo(5.6435643564, 1e-8));
      expect(margin.brokerFee, 21000);
      expect(margin.salesTax, 22000);
      expect(margin.isProfitable, isTrue);
    });

    test('calculates break-even sell price', () {
      final breakEven = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(breakEven, greaterThan(1010000));
      expect(breakEven, closeTo(1041237.1134, 1e-4));
    });

    test('uses default broker fee and sales tax percentages', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000,
        sellPrice: 1100,
      );

      // With 1% broker fee, 2% sales tax:
      // buyTotal  = 1000 * 1.01 = 1010
      // sellNet   = 1100 * 0.97 = 1067
      // profit    = 1067 - 1010 = 57
      // brokerFee = 1000*0.01 + 1100*0.01 = 21
      // salesTax  = 1100 * 0.02 = 22
      expect(margin.buyPrice, 1000);
      expect(margin.sellPrice, 1100);
      expect(margin.buyTotal, 1010);
      expect(margin.sellNet, 1067);
      expect(margin.profit, 57);
      expect(margin.brokerFee, 21);
      expect(margin.salesTax, 22);
    });

    test('marks negative profit as not profitable', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1000000,
      );

      expect(margin.profit, lessThan(0));
      expect(margin.marginPercent, lessThan(0));
      expect(margin.isProfitable, isFalse);
    });

    // ---------------------------------------------------------------
    // Boundary tests
    // ---------------------------------------------------------------

    test('returns zero margin percent for zero buy total', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 0,
        sellPrice: 0,
        brokerFeePercent: 0,
        salesTaxPercent: 0,
      );

      expect(margin.buyTotal, 0);
      expect(margin.profit, 0);
      expect(margin.marginPercent, 0);
      expect(margin.isProfitable, isFalse);
    });

    test('break-even sell price is zero for zero buy price', () {
      final breakEven = TradeCalculator.breakEvenSellPrice(buyPrice: 0);

      expect(breakEven, 0);
    });

    // ---------------------------------------------------------------
    // Error-path tests
    // ---------------------------------------------------------------

    test('throws ArgumentError for negative prices', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: -1, sellPrice: 100),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 100, sellPrice: -1),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for invalid fee percentages', () {
      // Negative brokerFeePercent
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 200,
          brokerFeePercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Negative salesTaxPercent
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 200,
          salesTaxPercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Sum >= 100 — calculateMargin
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 200,
          brokerFeePercent: 50,
          salesTaxPercent: 50,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Sum >= 100 — breakEvenSellPrice
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: 50,
          salesTaxPercent: 50,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
