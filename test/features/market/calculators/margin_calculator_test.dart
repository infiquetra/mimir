import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
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
      expect(result.marginPercent, closeTo(5.643564356435644, 0.0001));
      expect(result.brokerFee, 21000);
      expect(result.salesTax, 22000);
      expect(result.isProfitable, isTrue);
    });

    test('identifies unprofitable trades', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1100000,
        sellPrice: 1080000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result.profit, lessThan(0));
      expect(result.marginPercent, lessThan(0));
      expect(result.isProfitable, isFalse);
    });

    test('uses default broker fee and sales tax percentages', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1100000,
      );

      expect(result.buyPrice, 1000000);
      expect(result.sellPrice, 1100000);
      expect(result.buyTotal, 1010000);
      expect(result.sellNet, 1067000);
      expect(result.profit, 57000);
      expect(result.marginPercent, closeTo(5.643564356435644, 0.0001));
      expect(result.brokerFee, 21000);
      expect(result.salesTax, 22000);
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates break-even sell price', () {
      final price = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(price, closeTo(1041237.1134020619, 0.0001));
      expect(price, greaterThan(1010000));
    });

    test('break-even price produces approximately zero profit', () {
      final breakEven = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: breakEven,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(margin.profit, closeTo(0.0, 0.0001));
      expect(margin.marginPercent, closeTo(0.0, 0.0001));
    });
  });

  group('TradeCalculator input validation', () {
    test('throws ArgumentError for non-positive buy prices', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 0, sellPrice: 1100000),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(buyPrice: -1, sellPrice: 1100000),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: 0),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: -1),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for invalid sell prices', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 1000000, sellPrice: -1),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: double.nan,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: double.infinity,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for invalid fee percentages', () {
      // Negative brokerFeePercent
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: -1,
        ),
        throwsArgumentError,
      );

      // Negative salesTaxPercent
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          salesTaxPercent: -1,
        ),
        throwsArgumentError,
      );

      // Invalid brokerFeePercent in breakEvenSellPrice
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: double.nan,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          salesTaxPercent: double.infinity,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when combined sell-side fees are 100 percent '
        'or more', () {
      // Exactly 100%
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );

      // Above 100%
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: 60.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: 60.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
    });
  });
}
