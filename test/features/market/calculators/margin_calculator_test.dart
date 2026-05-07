import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('calculateMargin', () {
    test('computes profitable trade with default fees', () {
      // buyPrice=100, sellPrice=120, brokerFee=1%, salesTax=2%
      // buyTotal = 100 * 1.01 = 101
      // sellNet = 120 * 0.97 = 116.4
      // profit = 116.4 - 101 = 15.4
      // marginPercent = 15.4 / 101 * 100 ≈ 15.2475...
      // brokerFee = 100*0.01 + 120*0.01 = 1 + 1.2 = 2.2
      // salesTax = 120 * 0.02 = 2.4
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: 120,
      );

      expect(margin.buyPrice, 100);
      expect(margin.sellPrice, 120);
      expect(margin.buyTotal, closeTo(101, 1e-10));
      expect(margin.sellNet, closeTo(116.4, 1e-10));
      expect(margin.profit, closeTo(15.4, 1e-10));
      expect(margin.marginPercent, closeTo(15.247524752475247, 1e-10));
      expect(margin.brokerFee, closeTo(2.2, 1e-10));
      expect(margin.salesTax, closeTo(2.4, 1e-10));
    });

    test('computes profitable trade with custom fees', () {
      // buyPrice=500, sellPrice=600, brokerFee=3%, salesTax=1.5%
      // buyTotal = 500 * 1.03 = 515
      // sellNet = 600 * (1 - 0.03 - 0.015) = 600 * 0.955 = 573
      // profit = 573 - 515 = 58
      // marginPercent = 58 / 515 * 100 ≈ 11.2621...
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 500,
        sellPrice: 600,
        brokerFeePercent: 3.0,
        salesTaxPercent: 1.5,
      );

      expect(margin.buyTotal, closeTo(515, 1e-10));
      expect(margin.sellNet, closeTo(573, 1e-10));
      expect(margin.profit, closeTo(58, 1e-10));
      expect(margin.marginPercent, closeTo(11.262135922330097, 1e-10));
      expect(margin.brokerFee, closeTo(33, 1e-10));
      expect(margin.salesTax, closeTo(9, 1e-10));
    });

    test('computes unprofitable trade as negative profit', () {
      // buyPrice=1000, sellPrice=950, default fees
      // buyTotal = 1000 * 1.01 = 1010
      // sellNet = 950 * 0.97 = 921.5
      // profit = 921.5 - 1010 = -88.5
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000,
        sellPrice: 950,
      );

      expect(margin.profit, closeTo(-88.5, 1e-10));
      expect(margin.marginPercent, closeTo(-8.762376237623776, 1e-10));
      expect(margin.isProfitable, isFalse);
    });

    test('break-even trade is not profitable', () {
      // Use breakEvenSellPrice to compute exact break-even, then verify
      // profit is zero (or near-zero due to floating point).
      final breakEven = TradeCalculator.breakEvenSellPrice(buyPrice: 100);
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: breakEven,
      );

      expect(margin.profit, closeTo(0, 1e-10));
      expect(margin.isProfitable, isFalse);
    });

    test('throws on zero buy price', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 0, sellPrice: 10),
        throwsArgumentError,
      );
    });

    test('throws on negative buy price', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: -5, sellPrice: 10),
        throwsArgumentError,
      );
    });

    test('throws on zero sell price', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 10, sellPrice: 0),
        throwsArgumentError,
      );
    });

    test('throws on negative sell price', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 10, sellPrice: -5),
        throwsArgumentError,
      );
    });

    test('throws on negative broker fee percent', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 10,
          sellPrice: 20,
          brokerFeePercent: -1,
        ),
        throwsArgumentError,
      );
    });

    test('throws on negative sales tax percent', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 10,
          sellPrice: 20,
          salesTaxPercent: -0.5,
        ),
        throwsArgumentError,
      );
    });

    test('throws when broker fee plus sales tax equals 100%', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 10,
          sellPrice: 20,
          brokerFeePercent: 50,
          salesTaxPercent: 50,
        ),
        throwsArgumentError,
      );
    });

    test('throws when broker fee plus sales tax exceeds 100%', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 10,
          sellPrice: 20,
          brokerFeePercent: 60,
          salesTaxPercent: 50,
        ),
        throwsArgumentError,
      );
    });

    test('zero fees compute correctly', () {
      // No broker fee and no sales tax: trivial profit = sellPrice - buyPrice
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: 150,
        brokerFeePercent: 0,
        salesTaxPercent: 0,
      );

      expect(margin.buyTotal, closeTo(100, 1e-10));
      expect(margin.sellNet, closeTo(150, 1e-10));
      expect(margin.profit, closeTo(50, 1e-10));
      expect(margin.marginPercent, closeTo(50, 1e-10));
      expect(margin.brokerFee, closeTo(0, 1e-10));
      expect(margin.salesTax, closeTo(0, 1e-10));
      expect(margin.isProfitable, isTrue);
    });
  });

  group('breakEvenSellPrice', () {
    test('computes break-even with default fees', () {
      // buyPrice=100, brokerFee=1%, salesTax=2%
      // buyTotal = 100 * 1.01 = 101
      // breakEven = 101 / 0.97 ≈ 104.1237...
      final price = TradeCalculator.breakEvenSellPrice(buyPrice: 100);

      expect(price, closeTo(104.12371134020618, 1e-10));
    });

    test('round-trips through calculateMargin with zero profit', () {
      final breakEven = TradeCalculator.breakEvenSellPrice(
        buyPrice: 250,
        brokerFeePercent: 2.5,
        salesTaxPercent: 1.5,
      );

      final margin = TradeCalculator.calculateMargin(
        buyPrice: 250,
        sellPrice: breakEven,
        brokerFeePercent: 2.5,
        salesTaxPercent: 1.5,
      );

      expect(margin.profit, closeTo(0, 1e-10));
      expect(margin.isProfitable, isFalse);
    });

    test('computes break-even with custom fees', () {
      // buyPrice=200, brokerFee=5%, salesTax=3%
      // buyTotal = 200 * 1.05 = 210
      // breakEven = 210 / (1 - 0.05 - 0.03) = 210 / 0.92 ≈ 228.2608...
      final price = TradeCalculator.breakEvenSellPrice(
        buyPrice: 200,
        brokerFeePercent: 5,
        salesTaxPercent: 3,
      );

      expect(price, closeTo(228.26086956521738, 1e-10));
    });

    test('computes break-even with zero fees', () {
      // With no fees, break-even = buyPrice
      final price = TradeCalculator.breakEvenSellPrice(
        buyPrice: 500,
        brokerFeePercent: 0,
        salesTaxPercent: 0,
      );

      expect(price, closeTo(500, 1e-10));
    });

    test('throws on zero buy price', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: 0),
        throwsArgumentError,
      );
    });

    test('throws on negative buy price', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: -10),
        throwsArgumentError,
      );
    });

    test('throws on negative broker fee percent', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 10,
          brokerFeePercent: -1,
        ),
        throwsArgumentError,
      );
    });

    test('throws on negative sales tax percent', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 10,
          salesTaxPercent: -0.5,
        ),
        throwsArgumentError,
      );
    });

    test('throws when fees sum to 100%', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 10,
          brokerFeePercent: 80,
          salesTaxPercent: 20,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeMargin', () {
    test('isProfitable is true for positive profit', () {
      const margin = TradeMargin(
        buyPrice: 100,
        sellPrice: 120,
        buyTotal: 101,
        sellNet: 116.4,
        profit: 15.4,
        marginPercent: 15.247,
        brokerFee: 2.2,
        salesTax: 2.4,
      );

      expect(margin.isProfitable, isTrue);
    });

    test('isProfitable is false for zero profit', () {
      const margin = TradeMargin(
        buyPrice: 100,
        sellPrice: 104.12,
        buyTotal: 101,
        sellNet: 101,
        profit: 0,
        marginPercent: 0,
        brokerFee: 2.04,
        salesTax: 2.08,
      );

      expect(margin.isProfitable, isFalse);
    });

    test('isProfitable is false for negative profit', () {
      const margin = TradeMargin(
        buyPrice: 1000,
        sellPrice: 950,
        buyTotal: 1010,
        sellNet: 921.5,
        profit: -88.5,
        marginPercent: -8.762,
        brokerFee: 19.5,
        salesTax: 19,
      );

      expect(margin.isProfitable, isFalse);
    });

    test('const constructor works', () {
      // Verify the const constructor compiles and fields are accessible
      const margin = TradeMargin(
        buyPrice: 10,
        sellPrice: 20,
        buyTotal: 10.1,
        sellNet: 19.4,
        profit: 9.3,
        marginPercent: 92.07,
        brokerFee: 0.3,
        salesTax: 0.4,
      );

      expect(margin.buyPrice, 10);
      expect(margin.isProfitable, isTrue);
    });
  });
}
