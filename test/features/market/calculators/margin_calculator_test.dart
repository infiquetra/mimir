import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('calculateMargin', () {
    test('uses default broker fee and sales tax', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: 130,
      );

      expect(result.buyPrice, 100.0);
      expect(result.sellPrice, 130.0);
      expect(result.buyTotal, closeTo(101.0, 1e-9));
      expect(result.sellNet, closeTo(126.1, 1e-9));
      expect(result.profit, closeTo(25.1, 1e-9));
      expect(result.marginPercent, closeTo(24.851485148515, 1e-9));
      expect(result.brokerFee, closeTo(2.3, 1e-9));
      expect(result.salesTax, closeTo(2.6, 1e-9));
      expect(result.isProfitable, isTrue);
    });

    test('reports unprofitable trades', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: 90,
      );

      expect(result.sellNet, closeTo(87.3, 1e-9));
      expect(result.profit, closeTo(-13.7, 1e-9));
      expect(result.marginPercent, closeTo(-13.564356435644, 1e-9));
      expect(result.isProfitable, isFalse);
    });

    test('uses custom fee percentages', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 200,
        sellPrice: 300,
        brokerFeePercent: 5.0,
        salesTaxPercent: 10.0,
      );

      // buyTotal = 200 * (1 + 5/100) = 210
      // sellNet = 300 * (1 - 5/100 - 10/100) = 300 * 0.85 = 255
      // profit = 255 - 210 = 45
      // marginPercent = (45 / 210) * 100 ≈ 21.428571428571
      // brokerFee = 200*0.05 + 300*0.05 = 10 + 15 = 25
      // salesTax = 300 * 0.10 = 30
      expect(result.buyTotal, closeTo(210.0, 1e-9));
      expect(result.sellNet, closeTo(255.0, 1e-9));
      expect(result.profit, closeTo(45.0, 1e-9));
      expect(result.marginPercent, closeTo(21.428571428571, 1e-9));
      expect(result.brokerFee, closeTo(25.0, 1e-9));
      expect(result.salesTax, closeTo(30.0, 1e-9));
    });

    test('throws for zero buy price', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 0,
          sellPrice: 100,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.toString(),
          'toString',
          contains('buyPrice'),
        )),
      );
    });

    test('large buyPrice (1,000,000) with default fees', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1300000,
      );

      expect(result.buyPrice, 1000000.0);
      expect(result.sellPrice, 1300000.0);
      expect(result.buyTotal, closeTo(1010000.0, 1e-9));
      expect(result.sellNet, closeTo(1261000.0, 1e-9));
      expect(result.profit, closeTo(251000.0, 1e-9));
      expect(result.marginPercent, closeTo(24.8514851485148, 1e-9));
      expect(result.isProfitable, isTrue);
    });
  });

  group('breakEvenSellPrice', () {
    test('uses fees to calculate minimum sell price', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100,
      );

      // buyTotal = 100 * 1.01 = 101
      // feeMultiplier = 1 - 0.01 - 0.02 = 0.97
      // breakEven = 101 / 0.97 ≈ 104.123711340206
      expect(result, closeTo(104.123711340206, 1e-9));
    });

    test('uses custom fee percentages', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 500,
        brokerFeePercent: 3.0,
        salesTaxPercent: 4.0,
      );

      // buyTotal = 500 * 1.03 = 515
      // feeMultiplier = 1 - 0.03 - 0.04 = 0.93
      // breakEven = 515 / 0.93 ≈ 553.763440860215
      expect(result, closeTo(553.763440860215, 1e-9));
    });

    test('throws for zero buy price', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 0,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.toString(),
          'toString',
          contains('buyPrice'),
        )),
      );
    });

    test('large buyPrice (1,000,000) break even', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
      );

      // buyTotal = 1000000 * 1.01 = 1010000
      // feeMultiplier = 1 - 0.01 - 0.02 = 0.97
      // breakEven = 1010000 / 0.97 ≈ 1041237.113402062
      expect(result, closeTo(1041237.113402062, 1e-9));
    });

    test('break-even price produces approximately zero profit', () {
      final breakEven = TradeCalculator.breakEvenSellPrice(buyPrice: 100);
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: breakEven,
      );

      expect(margin.profit, closeTo(0.0, 1e-6));
    });
  });

  group('validation', () {
    test('invalid negative prices throw ArgumentError', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: -1,
          sellPrice: 100,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.toString(),
          'toString',
          contains('buyPrice'),
        )),
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: -1,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.toString(),
          'toString',
          contains('sellPrice'),
        )),
      );
    });

    test('invalid negative fees throw ArgumentError', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: -1,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.toString(),
          'toString',
          contains('brokerFeePercent'),
        )),
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          salesTaxPercent: -1,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.toString(),
          'toString',
          contains('salesTaxPercent'),
        )),
      );
    });

    test('combined sell-side fees at or above 100 percent throw ArgumentError',
        () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: 60,
          salesTaxPercent: 40,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.toString(),
          'toString',
          contains('100'),
        )),
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: 50,
          salesTaxPercent: 50,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.toString(),
          'toString',
          contains('100'),
        )),
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: 60,
          salesTaxPercent: 40,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.toString(),
          'toString',
          contains('100'),
        )),
      );
    });

    test('invalid negative prices throw ArgumentError for breakEvenSellPrice',
        () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: -1,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.toString(),
          'toString',
          contains('buyPrice'),
        )),
      );
    });
  });
}
