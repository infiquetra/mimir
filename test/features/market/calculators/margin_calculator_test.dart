import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator', () {
    test('calculates margin correctly', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1100000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(margin.buyPrice, equals(1000000));
      expect(margin.sellPrice, equals(1100000));
      expect(margin.buyTotal, equals(1010000));
      expect(margin.sellNet, equals(1067000));
      expect(margin.profit, equals(57000));
      expect(margin.marginPercent, closeTo(5.6435643564, 0.0001));
      expect(margin.brokerFee, equals(21000));
      expect(margin.salesTax, equals(22000));
      expect(margin.isProfitable, isTrue);
    });

    test('calculates break-even sell price', () {
      final breakEven = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(breakEven, greaterThan(1010000));
      expect(breakEven, closeTo(1041237.1134, 0.0001));
    });

    test('marks losing trades as not profitable', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 900000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(margin.profit, lessThan(0));
      expect(margin.marginPercent, lessThan(0));
      expect(margin.isProfitable, isFalse);
    });

    test('uses default broker fee and sales tax percentages', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: 200,
      );

      expect(margin.buyTotal, equals(101));
      expect(margin.sellNet, equals(194));
      expect(margin.brokerFee, equals(3));
      expect(margin.salesTax, equals(4));
    });

    test('throws ArgumentError for invalid prices and fee rates', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 0, sellPrice: 100),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: -1, sellPrice: 100),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 100, sellPrice: -1),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: -0.1,
        ),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          salesTaxPercent: -0.1,
        ),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: 60,
          salesTaxPercent: 40,
        ),
        throwsArgumentError,
      );

      // Break-even validation
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: 0),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: -1),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: -0.1,
        ),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: 60,
          salesTaxPercent: 40,
        ),
        throwsArgumentError,
      );
    });
  });
}
