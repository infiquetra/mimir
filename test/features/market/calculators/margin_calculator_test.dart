import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator', () {
    // -------------------------------------------------------------------------
    // Named tests from the blueprint
    // -------------------------------------------------------------------------

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
      expect(margin.marginPercent, closeTo(5.643564356435644, 1e-9));
      expect(margin.brokerFee, 21000);
      expect(margin.salesTax, 22000);
      expect(margin.isProfitable, isTrue);
    });

    test('calculates break-even sell price', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result, closeTo(1041237.1134020619, 1e-9));
      expect(result, greaterThan(1010000));
    });

    // -------------------------------------------------------------------------
    // Edge-case tests
    // -------------------------------------------------------------------------

    test('marks negative-profit trades as not profitable', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1000000,
      );

      expect(margin.profit, lessThan(0));
      expect(margin.marginPercent, lessThan(0));
      expect(margin.isProfitable, isFalse);
    });

    test('uses custom broker fee and sales tax percentages', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 500,
        sellPrice: 750,
        brokerFeePercent: 2.5,
        salesTaxPercent: 4.0,
      );

      expect(margin.buyPrice, 500);
      expect(margin.sellPrice, 750);
      expect(margin.buyTotal, closeTo(512.5, 1e-9));
      expect(margin.sellNet, closeTo(701.25, 1e-9));
      expect(margin.profit, closeTo(188.75, 1e-9));
      expect(margin.marginPercent, closeTo(36.82926829268293, 1e-9));
      expect(margin.brokerFee, closeTo(31.25, 1e-9));
      expect(margin.salesTax, closeTo(30.0, 1e-9));
      expect(margin.isProfitable, isTrue);
    });

    test('calculates break-even with custom fees', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 500,
        brokerFeePercent: 2.5,
        salesTaxPercent: 4.0,
      );

      // buyTotal = 500 * 1.025 = 512.5
      // sellSideRate = 1 - 0.025 - 0.04 = 0.935
      // 512.5 / 0.935 = 548.1283422459893
      expect(result, closeTo(548.1283422459893, 1e-9));
      expect(result, greaterThan(512.5));
    });

    // -------------------------------------------------------------------------
    // Validation-error tests
    // -------------------------------------------------------------------------

    test('rejects invalid prices and fee percentages', () {
      // buyPrice must be > 0
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 0, sellPrice: 100),
        throwsArgumentError,
      );

      // sellPrice must be > 0
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 100, sellPrice: -1),
        throwsArgumentError,
      );

      // brokerFeePercent must be >= 0
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 200,
          brokerFeePercent: -0.1,
        ),
        throwsArgumentError,
      );

      // salesTaxPercent must be >= 0
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 200,
          salesTaxPercent: -0.1,
        ),
        throwsArgumentError,
      );

      // non-finite inputs
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.infinity,
          sellPrice: 100,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: double.nan,
        ),
        throwsArgumentError,
      );

      // combined fees >= 100%
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 200,
          brokerFeePercent: 50,
          salesTaxPercent: 50,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 200,
          brokerFeePercent: 60,
          salesTaxPercent: 50,
        ),
        throwsArgumentError,
      );
    });

    test('breakEvenSellPrice rejects invalid inputs', () {
      // buyPrice must be > 0
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: 0),
        throwsArgumentError,
      );

      // non-finite buyPrice
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: double.infinity),
        throwsArgumentError,
      );

      // negative fee
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: -1,
        ),
        throwsArgumentError,
      );

      // combined fees >= 100%
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: 50,
          salesTaxPercent: 60,
        ),
        throwsArgumentError,
      );
    });
  });
}
