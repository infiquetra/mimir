import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('calculates profitable margin with default fees', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
      );

      expect(result.buyPrice, 100.0);
      expect(result.sellPrice, 120.0);
      expect(result.buyTotal, 101.0);
      expect(result.sellNet, closeTo(116.4, 1e-9));
      expect(result.profit, closeTo(15.4, 1e-9));
      expect(result.marginPercent, closeTo(15.247524752475248, 1e-9));
      expect(result.brokerFee, closeTo(2.2, 1e-9));
      expect(result.salesTax, closeTo(2.4, 1e-9));
      expect(result.isProfitable, isTrue);
    });

    test('calculates loss margin and marks it unprofitable', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 90.0,
      );

      expect(result.profit, lessThan(0));
      expect(result.marginPercent, lessThan(0));
      expect(result.isProfitable, isFalse);
    });

    test('supports custom broker fee and sales tax percentages', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000.0,
        sellPrice: 1200.0,
        brokerFeePercent: 0.5,
        salesTaxPercent: 1.5,
      );

      expect(result.buyTotal, 1005.0);
      expect(result.sellNet, 1176.0);
      expect(result.profit, 171.0);
      expect(result.brokerFee, 11.0);
      expect(result.salesTax, 18.0);
    });

    test('returns zero margin percent when buy total is zero', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 0.0,
        sellPrice: 0.0,
      );

      expect(result.buyTotal, 0.0);
      expect(result.profit, 0.0);
      expect(result.marginPercent, 0.0);
      expect(result.isProfitable, isFalse);
    });

    test('throws ArgumentError for invalid margin inputs', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: -1.0, sellPrice: 100.0),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 100.0, sellPrice: -1.0),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          brokerFeePercent: -0.5,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          salesTaxPercent: -0.5,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          brokerFeePercent: double.nan,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates break-even sell price with default fees', () {
      final result = TradeCalculator.breakEvenSellPrice(buyPrice: 100.0);

      // buyTotal = 100 * 1.01 = 101
      // sellRetentionRate = 1 - 0.01 - 0.02 = 0.97
      // breakEven = 101 / 0.97 ≈ 104.12371134020619
      expect(result, closeTo(104.12371134020619, 1e-9));
    });

    test('calculates break-even sell price with custom fees', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000.0,
        brokerFeePercent: 0.5,
        salesTaxPercent: 1.5,
      );

      // buyTotal = 1000 * 1.005 = 1005
      // sellRetentionRate = 1 - 0.005 - 0.015 = 0.98
      // breakEven = 1005 / 0.98 ≈ 1025.5102040816327
      expect(result, closeTo(1025.5102040816327, 1e-9));
    });

    test(
      'throws ArgumentError when fee percentages eliminate sell proceeds',
      () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 100.0,
            brokerFeePercent: 50.0,
            salesTaxPercent: 50.0,
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
