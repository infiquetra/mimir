import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator', () {
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
      expect(result.sellNet, closeTo(1067000, 0.001));
      expect(result.profit, closeTo(57000, 0.001));
      expect(result.marginPercent, closeTo(5.6435643564, 0.000001));
      expect(result.brokerFee, 21000);
      expect(result.salesTax, 22000);
      expect(result.isProfitable, isTrue);
    });

    test('calculates break-even sell price', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result, closeTo(1041237.1134020619, 0.0001));
      expect(result, greaterThan(1010000));
    });

    test('reports unprofitable trades', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1020000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result.profit, lessThan(0));
      expect(result.marginPercent, lessThan(0));
      expect(result.isProfitable, isFalse);
    });

    test('accepts zero buyPrice with zero margin', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 0,
        sellPrice: 1100000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result.buyPrice, 0);
      expect(result.sellPrice, 1100000);
      expect(result.buyTotal, 0);
      expect(result.sellNet, closeTo(1067000, 0.001));
      expect(result.profit, closeTo(1067000, 0.001));
      expect(result.marginPercent, 0.0);
      expect(result.isProfitable, isTrue);
    });

    test('rejects negative prices', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: -1,
          sellPrice: 1100000,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: -1,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: -1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid fee and tax percentages', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: -1.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          salesTaxPercent: -1.0,
        ),
        throwsArgumentError,
      );

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
          brokerFeePercent: 100.0,
          salesTaxPercent: 0.0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects NaN and Infinity inputs', () {
      // NaN buyPrice
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.nan,
          sellPrice: 1100000,
        ),
        throwsArgumentError,
      );

      // Infinity buyPrice
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.infinity,
          sellPrice: 1100000,
        ),
        throwsArgumentError,
      );

      // NaN brokerFee
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: double.nan,
        ),
        throwsArgumentError,
      );

      // Infinity salesTax
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          salesTaxPercent: double.infinity,
        ),
        throwsArgumentError,
      );
    });
  });
}
