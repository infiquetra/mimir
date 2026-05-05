import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('calculates default station trading margin from blueprint formula',
        () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
      );

      expect(result.buyPrice, 100.0);
      expect(result.sellPrice, 120.0);
      expect(result.buyTotal, closeTo(101.0, 1e-10));
      expect(result.sellNet, closeTo(116.4, 1e-10));
      expect(result.profit, closeTo(15.4, 1e-10));
      expect(result.marginPercent, closeTo(15.247524752475248, 1e-10));
      expect(result.brokerFee, closeTo(2.2, 1e-10));
      expect(result.salesTax, closeTo(2.4, 1e-10));
      expect(result.isProfitable, isTrue);
    });

    test('calculates loss-making trade as not profitable', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 95.0,
      );

      expect(result.profit, lessThan(0));
      expect(result.isProfitable, isFalse);
    });

    test('uses custom broker fee and sales tax percentages', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 200.0,
        sellPrice: 250.0,
        brokerFeePercent: 2.5,
        salesTaxPercent: 3.5,
      );

      // buyTotal = 200 * (1 + 2.5/100) = 200 * 1.025 = 205
      expect(result.buyTotal, closeTo(205.0, 1e-10));
      // sellNet = 250 * (1 - 2.5/100 - 3.5/100) = 250 * 0.94 = 235
      expect(result.sellNet, closeTo(235.0, 1e-10));
      // profit = 235 - 205 = 30
      expect(result.profit, closeTo(30.0, 1e-10));
      // marginPercent = (30/205) * 100 ≈ 14.634...
      expect(result.marginPercent, closeTo(14.634146341463415, 1e-10));
      // brokerFee = 200*2.5/100 + 250*2.5/100 = 5 + 6.25 = 11.25
      expect(result.brokerFee, closeTo(11.25, 1e-10));
      // salesTax = 250 * 3.5/100 = 8.75
      expect(result.salesTax, closeTo(8.75, 1e-10));
      expect(result.isProfitable, isTrue);
    });

    test('returns zero margin percent for zero buy total', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 0.0,
        sellPrice: 0.0,
      );

      expect(result.buyTotal, 0.0);
      expect(result.marginPercent, 0.0);
      expect(result.marginPercent.isNaN, isFalse);
      expect(result.isProfitable, isFalse);
    });

    test('throws ArgumentError for negative or non-finite price and fee inputs',
        () {
      // Negative buyPrice
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: -1.0,
          sellPrice: 120.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Negative sellPrice
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: -1.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Negative fee
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          brokerFeePercent: -0.5,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // NaN
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.nan,
          sellPrice: 120.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Infinite
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.infinity,
          sellPrice: 120.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Sell-side fees >= 100
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          brokerFeePercent: 60.0,
          salesTaxPercent: 40.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Sell-side fees > 100
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          brokerFeePercent: 60.0,
          salesTaxPercent: 50.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates default break-even sell price', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100.0,
      );

      // buyTotal = 100 * 1.01 = 101
      // denominator = 1 - 0.01 - 0.02 = 0.97
      // result = 101 / 0.97 ≈ 104.1237...
      expect(result, closeTo(104.12371134020619, 1e-10));
    });

    test('calculates break-even with custom fees', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 200.0,
        brokerFeePercent: 2.0,
        salesTaxPercent: 3.0,
      );

      // buyTotal = 200 * 1.02 = 204
      // denominator = 1 - 0.02 - 0.03 = 0.95
      // result = 204 / 0.95 ≈ 214.7368...
      expect(result, closeTo(214.73684210526315, 1e-10));
    });

    test('throws ArgumentError when sell-side fees make denominator invalid',
        () {
      // broker + salesTax = 100
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: 60.0,
          salesTaxPercent: 40.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // broker + salesTax > 100
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: 60.0,
          salesTaxPercent: 50.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('TradeMargin', () {
    test('isProfitable is true only for positive profit', () {
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
      expect(profitable.isProfitable, isTrue);

      const breakeven = TradeMargin(
        buyPrice: 100,
        sellPrice: 103.09,
        buyTotal: 101,
        sellNet: 101,
        profit: 0,
        marginPercent: 0,
        brokerFee: 2.03,
        salesTax: 2.06,
      );
      expect(breakeven.isProfitable, isFalse);

      const loss = TradeMargin(
        buyPrice: 100,
        sellPrice: 95,
        buyTotal: 101,
        sellNet: 92.15,
        profit: -8.85,
        marginPercent: -8.76,
        brokerFee: 1.95,
        salesTax: 1.9,
      );
      expect(loss.isProfitable, isFalse);
    });
  });
}
