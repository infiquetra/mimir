import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('calculates margin correctly', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1100000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result.buyTotal, 1010000);
      expect(result.sellNet, 1067000);
      expect(result.profit, 57000);
      expect(result.marginPercent, closeTo(5.6435643564, 0.0001));
      expect(result.brokerFee, 21000);
      expect(result.salesTax, 22000);
      expect(result.isProfitable, isTrue);
    });

    test('identifies unprofitable trades', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result.profit, lessThan(0));
      expect(result.marginPercent, lessThan(0));
      expect(result.isProfitable, isFalse);
    });

    test('supports custom fee and tax percentages', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 500000,
        sellPrice: 600000,
        brokerFeePercent: 2.0,
        salesTaxPercent: 3.0,
      );

      // buyTotal = 500000 * 1.02 = 510000
      expect(result.buyTotal, 510000);
      // sellNet = 600000 * (1 - 0.02 - 0.03) = 600000 * 0.95 = 570000
      expect(result.sellNet, 570000);
      // profit = 570000 - 510000 = 60000
      expect(result.profit, 60000);
      // marginPercent = (60000 / 510000) * 100 ≈ 11.7647
      expect(result.marginPercent, closeTo(11.7647, 0.001));
      // brokerFee = 500000*0.02 + 600000*0.02 = 10000 + 12000 = 22000
      expect(result.brokerFee, 22000);
      // salesTax = 600000 * 0.03 = 18000
      expect(result.salesTax, 18000);
      expect(result.isProfitable, isTrue);
    });

    test('throws ArgumentError for invalid calculateMargin inputs', () {
      // buyPrice: 0
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 0,
          sellPrice: 1100000,
        ),
        throwsArgumentError,
      );

      // negative sellPrice
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: -100,
        ),
        throwsArgumentError,
      );

      // negative brokerFeePercent
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: -1.0,
        ),
        throwsArgumentError,
      );

      // negative salesTaxPercent
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          salesTaxPercent: -1.0,
        ),
        throwsArgumentError,
      );

      // double.nan
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.nan,
          sellPrice: 1100000,
        ),
        throwsArgumentError,
      );

      // double.infinity
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.infinity,
          sellPrice: 1100000,
        ),
        throwsArgumentError,
      );

      // negative infinity
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.negativeInfinity,
          sellPrice: 1100000,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates break-even sell price', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result, closeTo(1041237.1134020619, 0.0001));
      expect(result, greaterThan(1010000));
    });

    test('break-even price yields zero profit within rounding tolerance', () {
      final breakEven = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: breakEven,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(margin.profit, closeTo(0, 0.01));
      expect(margin.marginPercent, closeTo(0, 0.001));
    });

    test('throws ArgumentError when fees consume entire sell price', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for invalid breakEvenSellPrice inputs', () {
      // non-finite buy price (nan)
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: double.nan,
        ),
        throwsArgumentError,
      );

      // non-finite buy price (infinity)
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: double.infinity,
        ),
        throwsArgumentError,
      );

      // non-positive buy price
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 0,
        ),
        throwsArgumentError,
      );

      // negative broker fee
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: -1.0,
        ),
        throwsArgumentError,
      );

      // negative sales tax
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          salesTaxPercent: -1.0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeMargin.isProfitable', () {
    test('returns true for positive profit', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1100000,
      );
      expect(margin.isProfitable, isTrue);
    });

    test('returns false for zero profit', () {
      // At break-even, profit is 0, so isProfitable should be false
      final breakEven = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: breakEven,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );
      // Due to floating point, profit might be a tiny epsilon, but isProfitable checks > 0
      // After verifying it's close to 0, isProfitable should be false
      expect(margin.profit.abs(), lessThan(1.0));
      expect(margin.isProfitable, isFalse);
    });

    test('returns false for negative profit', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 900000,
      );
      expect(margin.isProfitable, isFalse);
    });
  });
}
