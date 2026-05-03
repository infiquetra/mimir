import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('calculates profitable station trade with default fees', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 150.0,
      );

      expect(result.buyPrice, 100.0);
      expect(result.sellPrice, 150.0);
      expect(result.buyTotal, closeTo(101.0, 0.000001));
      expect(result.sellNet, closeTo(145.5, 0.000001));
      expect(result.profit, closeTo(44.5, 0.000001));
      expect(result.marginPercent, closeTo(44.05940594059406, 0.000001));
      expect(result.brokerFee, closeTo(2.5, 0.000001));
      expect(result.salesTax, closeTo(3.0, 0.000001));
      expect(result.isProfitable, true);
    });

    test('calculates loss-making trade as not profitable', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 90.0,
      );

      expect(result.profit, closeTo(-13.7, 0.000001));
      expect(result.isProfitable, false);
    });

    test('supports custom broker fee and sales tax percentages', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 200.0,
        sellPrice: 250.0,
        brokerFeePercent: 2.0,
        salesTaxPercent: 1.5,
      );

      // buyTotal  = 200 * (1 + 2/100)   = 204.0
      // sellNet   = 250 * (1 - 2/100 - 1.5/100) = 250 * 0.965 = 241.25
      // profit    = 241.25 - 204.0 = 37.25
      // marginPct = (37.25 / 204.0) * 100 = 18.259803921568627
      // brokerFee = 200*2/100 + 250*2/100 = 4 + 5 = 9.0
      // salesTax  = 250 * 1.5/100 = 3.75
      expect(result.buyTotal, closeTo(204.0, 0.000001));
      expect(result.sellNet, closeTo(241.25, 0.000001));
      expect(result.profit, closeTo(37.25, 0.000001));
      expect(result.marginPercent, closeTo(18.259803921568627, 0.000001));
      expect(result.brokerFee, closeTo(9.0, 0.000001));
      expect(result.salesTax, closeTo(3.75, 0.000001));
      expect(result.isProfitable, true);
    });

    test('returns zero margin percent when buy total is zero', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 0.0,
        sellPrice: 0.0,
        brokerFeePercent: 0.0,
        salesTaxPercent: 0.0,
      );

      expect(result.buyTotal, 0.0);
      expect(result.profit, 0.0);
      expect(result.marginPercent, 0.0);
      expect(result.isProfitable, false);
    });

    test('rejects invalid prices and fee percentages', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.nan,
          sellPrice: 100.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: double.infinity,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 100.0,
          brokerFeePercent: -1.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 100.0,
          brokerFeePercent: 1.0,
          salesTaxPercent: double.nan,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: -50.0,
          sellPrice: 100.0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects combined sell-side fees at or above 100 percent', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 200.0,
          brokerFeePercent: 60.0,
          salesTaxPercent: 40.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 200.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates break-even sell price with default fees', () {
      // buyTotal = 100 * 1.01 = 101.0
      // sellPrice = 101.0 / (1 - 0.01 - 0.02) = 101.0 / 0.97
      final price = TradeCalculator.breakEvenSellPrice(buyPrice: 100.0);

      expect(price, closeTo(104.12371134020619, 0.000001));
    });

    test('calculates break-even sell price with custom fees', () {
      // buyTotal = 100 * (1 + 2/100) = 102.0
      // sellPrice = 102.0 / (1 - 2/100 - 3/100) = 102.0 / 0.95
      final price = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100.0,
        brokerFeePercent: 2.0,
        salesTaxPercent: 3.0,
      );

      expect(price, closeTo(107.36842105263158, 0.000001));
    });

    test('rejects invalid inputs', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: double.nan),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: -1.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: 60.0,
          salesTaxPercent: 40.0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeMargin', () {
    test('isProfitable is true only when profit is positive', () {
      const profitable = TradeMargin(
        buyPrice: 100.0,
        sellPrice: 150.0,
        buyTotal: 101.0,
        sellNet: 145.5,
        profit: 44.5,
        marginPercent: 44.06,
        brokerFee: 2.5,
        salesTax: 3.0,
      );
      expect(profitable.isProfitable, true);

      const breakEven = TradeMargin(
        buyPrice: 100.0,
        sellPrice: 104.12,
        buyTotal: 101.0,
        sellNet: 101.0,
        profit: 0.0,
        marginPercent: 0.0,
        brokerFee: 2.04,
        salesTax: 2.08,
      );
      expect(breakEven.isProfitable, false);

      const loss = TradeMargin(
        buyPrice: 100.0,
        sellPrice: 90.0,
        buyTotal: 101.0,
        sellNet: 87.3,
        profit: -13.7,
        marginPercent: -13.56,
        brokerFee: 1.9,
        salesTax: 1.8,
      );
      expect(loss.isProfitable, false);
    });
  });
}
