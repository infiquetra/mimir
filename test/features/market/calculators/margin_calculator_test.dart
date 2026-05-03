import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('calculates profitable station trade with default fees', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 200.0,
      );

      expect(result.buyPrice, 100.0);
      expect(result.sellPrice, 200.0);
      expect(result.buyTotal, closeTo(101.0, 1e-6));
      expect(result.sellNet, closeTo(194.0, 1e-6));
      expect(result.profit, closeTo(93.0, 1e-6));
      expect(result.marginPercent, closeTo(92.07920792079208, 1e-6));
      expect(result.brokerFee, closeTo(3.0, 1e-6));
      expect(result.salesTax, closeTo(4.0, 1e-6));
      expect(result.isProfitable, true);
    });

    test('calculates unprofitable station trade', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 200.0,
        sellPrice: 100.0,
      );

      expect(result.profit, lessThan(0));
      expect(result.isProfitable, false);
    });

    test('uses custom broker fee and sales tax percentages', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 200.0,
        brokerFeePercent: 2.0,
        salesTaxPercent: 5.0,
      );

      // buyTotal = 100 * (1 + 2/100) = 102.0
      // sellNet = 200 * (1 - 2/100 - 5/100) = 200 * 0.93 = 186.0
      // profit = 186.0 - 102.0 = 84.0
      // brokerFee = 100*0.02 + 200*0.02 = 2.0 + 4.0 = 6.0
      // salesTax = 200*0.05 = 10.0
      expect(result.buyTotal, closeTo(102.0, 1e-6));
      expect(result.sellNet, closeTo(186.0, 1e-6));
      expect(result.profit, closeTo(84.0, 1e-6));
      expect(result.brokerFee, closeTo(6.0, 1e-6));
      expect(result.salesTax, closeTo(10.0, 1e-6));
      expect(result.isProfitable, true);
    });

    test('reports exact break-even margin as not profitable', () {
      // buyPrice=100, default fees => breakEven = 101/0.97 ≈ 104.12371...
      // At exactly break-even, profit should be ~0, isProfitable should be false
      final buyPrice = 100.0;
      final breakEven = TradeCalculator.breakEvenSellPrice(buyPrice: buyPrice);
      final result = TradeCalculator.calculateMargin(
        buyPrice: buyPrice,
        sellPrice: breakEven,
      );

      expect(result.profit, closeTo(0.0, 1e-9));
      expect(result.isProfitable, false);
    });

    test('throws ArgumentError for non-positive prices', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 0.0,
          sellPrice: 100.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: -1.0,
          sellPrice: 100.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 0.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: -1.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for non-finite prices', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.nan,
          sellPrice: 100.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.infinity,
          sellPrice: 100.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.negativeInfinity,
          sellPrice: 100.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for invalid fee percentages', () {
      // Negative broker fee
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 200.0,
          brokerFeePercent: -0.1,
        ),
        throwsA(isA<ArgumentError>()),
      );
      // NaN broker fee
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 200.0,
          brokerFeePercent: double.nan,
        ),
        throwsA(isA<ArgumentError>()),
      );
      // Negative sales tax
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 200.0,
          salesTaxPercent: -0.1,
        ),
        throwsA(isA<ArgumentError>()),
      );
      // NaN sales tax
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 200.0,
          salesTaxPercent: double.nan,
        ),
        throwsA(isA<ArgumentError>()),
      );
      // Combined fees >= 100 (division by zero at limit)
      // brokerFeePercent=50, salesTaxPercent=50 => combined = 100 (exactly at limit)
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 200.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
      // brokerFeePercent=60, salesTaxPercent=50 => combined = 110 (> limit)
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 200.0,
          brokerFeePercent: 60.0,
          salesTaxPercent: 50.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates break-even sell price with default fees', () {
      final result = TradeCalculator.breakEvenSellPrice(buyPrice: 100.0);

      // buyTotal = 100 * 1.01 = 101.0
      // breakEven = 101.0 / 0.97 ≈ 104.12371134...
      expect(result, closeTo(104.12371134020619, 1e-9));
    });

    test('calculates break-even sell price with custom fees', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100.0,
        brokerFeePercent: 2.0,
        salesTaxPercent: 5.0,
      );

      // buyTotal = 100 * 1.02 = 102.0
      // breakEven = 102.0 / 0.93 ≈ 109.6774193548387...
      expect(result, closeTo(109.6774193548387, 1e-9));
    });

    test('validates buy price and fees', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: 0.0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: -1.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('TradeMargin', () {
    test('isProfitable returns true when profit > 0', () {
      final margin = TradeMargin(
        buyPrice: 100.0,
        sellPrice: 200.0,
        buyTotal: 101.0,
        sellNet: 194.0,
        profit: 93.0,
        marginPercent: 92.08,
        brokerFee: 3.0,
        salesTax: 4.0,
      );

      expect(margin.isProfitable, true);
    });

    test('isProfitable returns false when profit == 0', () {
      final margin = TradeMargin(
        buyPrice: 100.0,
        sellPrice: 104.12371134020619,
        buyTotal: 101.0,
        sellNet: 101.0,
        profit: 0.0,
        marginPercent: 0.0,
        brokerFee: 1.0,
        salesTax: 2.082474226804124,
      );

      expect(margin.isProfitable, false);
    });

    test('isProfitable returns false when profit < 0', () {
      final margin = TradeMargin(
        buyPrice: 100.0,
        sellPrice: 90.0,
        buyTotal: 101.0,
        sellNet: 87.3,
        profit: -13.7,
        marginPercent: -13.56,
        brokerFee: 1.9,
        salesTax: 1.8,
      );

      expect(margin.isProfitable, false);
    });
  });
}
