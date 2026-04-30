import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator', () {
    // --- Spec-named test: calculates margin correctly ---
    test('calculates margin correctly', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1100000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result.buyPrice, 1000000);
      expect(result.sellPrice, 1100000);
      expect(result.buyTotal, 1010000);
      expect(result.sellNet, 1067000);
      expect(result.profit, 57000);
      expect(result.marginPercent, closeTo(5.6435643564, 1e-9));
      expect(result.brokerFee, 21000);
      expect(result.salesTax, 22000);
      expect(result.isProfitable, isTrue);
    });

    // --- Spec-named test: calculates break-even sell price ---
    test('calculates break-even sell price', () {
      final price = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(price, closeTo(1041237.1134, 1e-5));
      expect(price, greaterThan(1010000));
    });

    // --- Additional coverage tests ---

    test('identifies unprofitable trades', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1000000,
      );

      expect(result.profit, lessThan(0));
      expect(result.marginPercent, lessThan(0));
      expect(result.isProfitable, isFalse);
    });

    test('supports custom broker fee and sales tax percentages', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 500,
        sellPrice: 750,
        brokerFeePercent: 2.5,
        salesTaxPercent: 1.5,
      );

      // buyTotal = 500 * (1 + 2.5/100) = 512.5
      expect(result.buyTotal, closeTo(512.5, 1e-9));
      // sellNet = 750 * (1 - 2.5/100 - 1.5/100) = 750 * 0.96 = 720
      expect(result.sellNet, closeTo(720.0, 1e-9));
      // profit = 720 - 512.5 = 207.5
      expect(result.profit, closeTo(207.5, 1e-9));
      // marginPercent = (207.5 / 512.5) * 100 ≈ 40.487804878
      expect(result.marginPercent, closeTo(40.487804878, 1e-8));
      // brokerFee = 500*2.5/100 + 750*2.5/100 = 12.5 + 18.75 = 31.25
      expect(result.brokerFee, closeTo(31.25, 1e-9));
      // salesTax = 750 * 1.5 / 100 = 11.25
      expect(result.salesTax, closeTo(11.25, 1e-9));
      expect(result.isProfitable, isTrue);
    });

    // --- Validation tests ---

    test('throws ArgumentError for non-positive prices', () {
      // buyPrice = 0
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 0, sellPrice: 1000000),
        throwsA(isA<ArgumentError>()),
      );

      // sellPrice = -1
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 1000000, sellPrice: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for invalid fee percentages', () {
      // Negative broker fee
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Combined sell-side fees >= 100
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: 50,
          salesTaxPercent: 50,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: 60,
          salesTaxPercent: 40,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Negative sales tax for breakEvenSellPrice
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          salesTaxPercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Combined >= 100 for breakEvenSellPrice
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: 50,
          salesTaxPercent: 50,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
