import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('calculates profitable margin with default fees', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 150.0,
      );

      // buyTotal = 100 * (1 + 1/100) = 101.0
      expect(margin.buyTotal, closeTo(101.0, 0.000001));
      // sellNet = 150 * (1 - 1/100 - 2/100) = 150 * 0.97 = 145.5
      expect(margin.sellNet, closeTo(145.5, 0.000001));
      // profit = 145.5 - 101.0 = 44.5
      expect(margin.profit, closeTo(44.5, 0.000001));
      // marginPercent = (44.5 / 101.0) * 100 ≈ 44.05940594059406
      expect(margin.marginPercent, closeTo(44.05940594059406, 0.000001));
      // brokerFee = 100 * 1/100 + 150 * 1/100 = 1.0 + 1.5 = 2.5
      expect(margin.brokerFee, closeTo(2.5, 0.000001));
      // salesTax = 150 * 2/100 = 3.0
      expect(margin.salesTax, closeTo(3.0, 0.000001));
      expect(margin.isProfitable, isTrue);
    });

    test('calculates loss margin when sell net is below buy total', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 90.0,
      );

      // buyTotal = 100 * 1.01 = 101.0
      expect(margin.buyTotal, closeTo(101.0, 0.000001));
      // sellNet = 90 * 0.97 = 87.3
      expect(margin.sellNet, closeTo(87.3, 0.000001));
      // profit = 87.3 - 101.0 = -13.7
      expect(margin.profit, lessThan(0));
      expect(margin.marginPercent, lessThan(0));
      expect(margin.isProfitable, isFalse);
    });

    test('treats exact break-even profit as not profitable', () {
      final breakEvenPrice = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100.0,
      );

      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: breakEvenPrice,
      );

      expect(margin.profit, closeTo(0.0, 0.000001));
      expect(margin.isProfitable, isFalse);
    });

    test('uses custom broker fee and sales tax percentages', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 200.0,
        sellPrice: 300.0,
        brokerFeePercent: 0.5,
        salesTaxPercent: 1.5,
      );

      // buyTotal = 200 * (1 + 0.5/100) = 200 * 1.005 = 201.0
      expect(margin.buyTotal, closeTo(201.0, 0.000001));
      // sellNet = 300 * (1 - 0.5/100 - 1.5/100) = 300 * 0.98 = 294.0
      expect(margin.sellNet, closeTo(294.0, 0.000001));
      // profit = 294.0 - 201.0 = 93.0
      expect(margin.profit, closeTo(93.0, 0.000001));
      // brokerFee = 200 * 0.5/100 + 300 * 0.5/100 = 1.0 + 1.5 = 2.5
      expect(margin.brokerFee, closeTo(2.5, 0.000001));
      // salesTax = 300 * 1.5/100 = 4.5
      expect(margin.salesTax, closeTo(4.5, 0.000001));
    });

    test('throws ArgumentError for buyPrice <= 0', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 0, sellPrice: 100),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: -50, sellPrice: 100),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for negative sellPrice', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 100, sellPrice: -10),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for negative brokerFeePercent', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 150,
          brokerFeePercent: -1,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for negative salesTaxPercent', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 150,
          salesTaxPercent: -3,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when combined sell-side fees >= 100', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 150,
          brokerFeePercent: 50,
          salesTaxPercent: 50,
        ),
        throwsArgumentError,
      );
      // Exactly 100% should also fail (sellFeeMultiplier <= 0)
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 150,
          brokerFeePercent: 100,
          salesTaxPercent: 0,
        ),
        throwsArgumentError,
      );
    });

    test('accepts zero sellPrice', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 0.0,
      );

      expect(margin.sellNet, closeTo(0.0, 0.000001));
      expect(margin.profit, lessThan(0));
      expect(margin.isProfitable, isFalse);
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates break-even sell price with default fees', () {
      final price = TradeCalculator.breakEvenSellPrice(buyPrice: 100.0);

      // buyTotal = 100 * 1.01 = 101.0
      // sellFeeMultiplier = 1 - 0.01 - 0.02 = 0.97
      // breakEven = 101.0 / 0.97 ≈ 104.12371134020619
      expect(price, closeTo(104.12371134020619, 0.000001));
    });

    test('calculates break-even sell price with custom fees', () {
      final price = TradeCalculator.breakEvenSellPrice(
        buyPrice: 200.0,
        brokerFeePercent: 0.5,
        salesTaxPercent: 1.5,
      );

      // buyTotal = 200 * (1 + 0.5/100) = 200 * 1.005 = 201.0
      // sellFeeMultiplier = 1 - 0.005 - 0.015 = 0.98
      // breakEven = 201.0 / 0.98 ≈ 205.10204081632654
      expect(price, closeTo(205.10204081632654, 0.000001));
    });

    test('throws ArgumentError for buyPrice <= 0', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: 0),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: -10),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for negative brokerFeePercent', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: -1,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for negative salesTaxPercent', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          salesTaxPercent: -3,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when combined sell-side fees >= 100', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: 50,
          salesTaxPercent: 50,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeMargin.isProfitable', () {
    test('returns true when profit is positive', () {
      final margin = TradeMargin(
        buyPrice: 100,
        sellPrice: 150,
        buyTotal: 101,
        sellNet: 145.5,
        profit: 44.5,
        marginPercent: 44.06,
        brokerFee: 2.5,
        salesTax: 3.0,
      );
      expect(margin.isProfitable, isTrue);
    });

    test('returns false when profit is zero', () {
      final margin = TradeMargin(
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

    test('returns false when profit is negative', () {
      final margin = TradeMargin(
        buyPrice: 100,
        sellPrice: 80,
        buyTotal: 101,
        sellNet: 77.6,
        profit: -23.4,
        marginPercent: -23.17,
        brokerFee: 1.8,
        salesTax: 1.6,
      );
      expect(margin.isProfitable, isFalse);
    });
  });
}
