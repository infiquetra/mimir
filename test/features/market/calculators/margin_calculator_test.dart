import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('returns correct buyTotal and sellNet with default rates', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
      );

      // buyTotal = 100 * (1 + 1/100) = 101
      expect(result.buyTotal, 101.0);
      // sellNet = 120 * (1 - 1/100 - 2/100) = 120 * 0.97 = 116.4
      expect(result.sellNet, closeTo(116.4, 1e-10));
    });

    test('calculates profit as sellNet - buyTotal', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
      );

      // profit = 116.4 - 101.0 = 15.4
      expect(result.profit, closeTo(15.4, 1e-10));
    });

    test('calculates marginPercent relative to buyTotal', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
      );

      // marginPercent = (15.4 / 101.0) * 100 ≈ 15.2475...
      expect(result.marginPercent, closeTo(15.247524752475248, 1e-10));
    });

    test('calculates brokerFee on both buy and sell sides', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
      );

      // buyFee = 100 * 1/100 = 1.0
      // sellFee = 120 * 1/100 = 1.2
      // total = 2.2
      expect(result.brokerFee, 2.2);
    });

    test('calculates salesTax on sell price only', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
      );

      // salesTax = 120 * 2/100 = 2.4
      expect(result.salesTax, 2.4);
    });

    test('preserves original buyPrice and sellPrice', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
      );

      expect(result.buyPrice, 100.0);
      expect(result.sellPrice, 120.0);
    });

    test('returns zero profit when sellPrice equals break-even', () {
      // break-even for buyPrice=100 is 100*1.01/(1-0.01-0.02) ≈ 104.123...
      final breakEven =
          TradeCalculator.breakEvenSellPrice(buyPrice: 100.0);
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: breakEven,
      );

      expect(result.profit, closeTo(0.0, 1e-10));
    });

    test('returns negative profit when selling below break-even', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 101.0,
      );

      expect(result.profit, lessThan(0.0));
    });

    test('handles sellPrice zero (total loss)', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 0.0,
      );

      // buyTotal = 101, sellNet = 0, profit = -101
      expect(result.buyTotal, 101.0);
      expect(result.sellNet, 0.0);
      expect(result.profit, -101.0);
    });

    test('handles zero brokerFeePercent', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
        brokerFeePercent: 0.0,
      );

      expect(result.brokerFee, 0.0);
      // buyTotal = 100.0, sellNet = 120 * 0.98 = 117.6
      expect(result.buyTotal, 100.0);
      expect(result.sellNet, 117.6);
    });

    test('handles zero salesTaxPercent', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
        salesTaxPercent: 0.0,
      );

      expect(result.salesTax, 0.0);
      // buyTotal = 101.0, sellNet = 120 * 0.99 = 118.8
      expect(result.sellNet, 118.8);
    });

    test('handles zero brokerFeePercent and zero salesTaxPercent', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
        brokerFeePercent: 0.0,
        salesTaxPercent: 0.0,
      );

      // buyTotal = sellNet = buyPrice/sellPrice, profit = 20
      expect(result.buyTotal, 100.0);
      expect(result.sellNet, 120.0);
      expect(result.profit, 20.0);
      expect(result.marginPercent, 20.0);
      expect(result.brokerFee, 0.0);
      expect(result.salesTax, 0.0);
    });

    // ── validation ────────────────────────────────────────────

    test('throws ArgumentError when buyPrice is zero', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 0.0,
          sellPrice: 120.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when buyPrice is negative', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: -100.0,
          sellPrice: 120.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when sellPrice is negative', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: -10.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when brokerFeePercent is negative', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          brokerFeePercent: -1.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when salesTaxPercent is negative', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          salesTaxPercent: -1.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when combined rates equal 100', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when combined rates exceed 100', () {
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
    test('returns correct break-even with default rates', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100.0,
      );

      // buyTotal = 101, divisor = 0.97 (97%)
      // breakEven = 101 / 0.97 ≈ 104.12371134020619
      expect(result, closeTo(104.12371134020619, 1e-10));
    });

    test('returns buyPrice when rates are zero', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100.0,
        brokerFeePercent: 0.0,
        salesTaxPercent: 0.0,
      );

      expect(result, 100.0);
    });

    test('returns higher break-even with higher brokerFeePercent', () {
      final lowFee = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100.0,
        brokerFeePercent: 1.0,
      );
      final highFee = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100.0,
        brokerFeePercent: 5.0,
      );

      expect(highFee, greaterThan(lowFee));
    });

    test('returns higher break-even with higher salesTaxPercent', () {
      final lowTax = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100.0,
        salesTaxPercent: 2.0,
      );
      final highTax = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100.0,
        salesTaxPercent: 5.0,
      );

      expect(highTax, greaterThan(lowTax));
    });

    test('handles small buyPrice', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 0.01,
      );

      expect(result, closeTo(0.01041237113402062, 1e-10));
    });

    // ── validation ────────────────────────────────────────────

    test('throws ArgumentError when buyPrice is zero', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: 0.0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when buyPrice is negative', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: -100.0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when brokerFeePercent is negative', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: -1.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when salesTaxPercent is negative', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          salesTaxPercent: -1.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when combined rates equal 100', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when combined rates exceed 100', () {
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

  group('TradeMargin.isProfitable', () {
    test('returns true when profit is positive', () {
      final margin = TradeMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
        buyTotal: 101.0,
        sellNet: 116.4,
        profit: 15.4,
        marginPercent: 15.2475,
        brokerFee: 2.2,
        salesTax: 2.4,
      );

      expect(margin.isProfitable, isTrue);
    });

    test('returns false when profit is negative', () {
      final margin = TradeMargin(
        buyPrice: 100.0,
        sellPrice: 90.0,
        buyTotal: 101.0,
        sellNet: 87.3,
        profit: -13.7,
        marginPercent: -13.564,
        brokerFee: 1.9,
        salesTax: 1.8,
      );

      expect(margin.isProfitable, isFalse);
    });

    test('returns false when profit is exactly zero', () {
      final margin = TradeMargin(
        buyPrice: 100.0,
        sellPrice: 100.0,
        buyTotal: 100.0,
        sellNet: 100.0,
        profit: 0.0,
        marginPercent: 0.0,
        brokerFee: 0.0,
        salesTax: 0.0,
      );

      expect(margin.isProfitable, isFalse);
    });
  });
}
