import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('calculateMargin', () {
    test('calculates profitable station trade margin with default fees', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
      );

      expect(result.buyTotal, moreOrLessEquals(101.0, epsilon: 0.000001));
      expect(result.sellNet, moreOrLessEquals(116.4, epsilon: 0.000001));
      expect(result.profit, moreOrLessEquals(15.4, epsilon: 0.000001));
      expect(result.marginPercent,
          moreOrLessEquals(15.247524752475247, epsilon: 0.000001));
      expect(result.brokerFee, moreOrLessEquals(2.2, epsilon: 0.000001));
      expect(result.salesTax, moreOrLessEquals(2.4, epsilon: 0.000001));
      expect(result.isProfitable, isTrue);
    });

    test(
        'calculates unprofitable margin when sell net is below buy total',
        () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 100.0,
      );

      expect(result.profit, moreOrLessEquals(-4.0, epsilon: 0.000001));
      expect(result.marginPercent,
          moreOrLessEquals(-3.9603960396039604, epsilon: 0.000001));
      expect(result.isProfitable, isFalse);
    });

    test('supports custom broker fee and sales tax percentages', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 250.0,
        sellPrice: 300.0,
        brokerFeePercent: 2.5,
        salesTaxPercent: 4.0,
      );

      expect(result.buyTotal, moreOrLessEquals(256.25, epsilon: 0.000001));
      expect(result.sellNet, moreOrLessEquals(280.5, epsilon: 0.000001));
      expect(result.profit, moreOrLessEquals(24.25, epsilon: 0.000001));
      expect(result.brokerFee, moreOrLessEquals(13.75, epsilon: 0.000001));
      expect(result.salesTax, moreOrLessEquals(12.0, epsilon: 0.000001));
    });

    test('throws ArgumentError for invalid prices', () {
      expect(
        () => TradeCalculator.calculateMargin(
            buyPrice: 0, sellPrice: 100.0),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(
            buyPrice: -1, sellPrice: 100.0),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(
            buyPrice: double.nan, sellPrice: 100.0),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(
            buyPrice: double.infinity, sellPrice: 100.0),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(
            buyPrice: 100.0, sellPrice: -1),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(
            buyPrice: 100.0, sellPrice: double.nan),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(
            buyPrice: 100.0, sellPrice: double.infinity),
        throwsArgumentError,
      );
    });

    test(
        'throws ArgumentError when total sell deductions are at least 100 percent',
        () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          brokerFeePercent: 60.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('breakEvenSellPrice', () {
    test('calculates break-even sell price with default fees', () {
      final result = TradeCalculator.breakEvenSellPrice(buyPrice: 100.0);

      // 101 / 0.97 = 104.12371134020619
      expect(result, moreOrLessEquals(104.12371134020619, epsilon: 0.000001));
    });

    test('calculates break-even sell price with custom fees', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 250.0,
        brokerFeePercent: 2.5,
        salesTaxPercent: 4.0,
      );

      // 256.25 / 0.935 = 274.06417112299465
      expect(result, moreOrLessEquals(274.06417112299465, epsilon: 0.000001));
    });

    test('throws ArgumentError for invalid break-even inputs', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: 0),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: -1),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: double.nan),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: double.infinity),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 100.0, brokerFeePercent: -1),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: 60.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeMargin', () {
    test('isProfitable is true only when profit is positive', () {
      const profitable = TradeMargin(
        buyPrice: 100,
        sellPrice: 120,
        buyTotal: 101,
        sellNet: 116.4,
        profit: 15.4,
        marginPercent: 15.2475,
        brokerFee: 2.2,
        salesTax: 2.4,
      );
      const breakeven = TradeMargin(
        buyPrice: 100,
        sellPrice: 100,
        buyTotal: 101,
        sellNet: 97,
        profit: 0,
        marginPercent: 0,
        brokerFee: 2.0,
        salesTax: 2.0,
      );
      const unprofitable = TradeMargin(
        buyPrice: 100,
        sellPrice: 100,
        buyTotal: 101,
        sellNet: 97,
        profit: -4,
        marginPercent: -3.96,
        brokerFee: 2.0,
        salesTax: 2.0,
      );

      expect(profitable.isProfitable, isTrue);
      expect(breakeven.isProfitable, isFalse);
      expect(unprofitable.isProfitable, isFalse);
    });

    test('toString includes all fields', () {
      const margin = TradeMargin(
        buyPrice: 100,
        sellPrice: 120,
        buyTotal: 101,
        sellNet: 116.4,
        profit: 15.4,
        marginPercent: 15.2475,
        brokerFee: 2.2,
        salesTax: 2.4,
      );

      final str = margin.toString();
      expect(str, contains('buyPrice: 100.0'));
      expect(str, contains('sellPrice: 120.0'));
      expect(str, contains('buyTotal: 101.0'));
      expect(str, contains('sellNet: 116.4'));
      expect(str, contains('profit: 15.4'));
      expect(str, contains('marginPercent: 15.2475'));
      expect(str, contains('brokerFee: 2.2'));
      expect(str, contains('salesTax: 2.4'));
      expect(str, contains('isProfitable: true'));
    });
  });
}
