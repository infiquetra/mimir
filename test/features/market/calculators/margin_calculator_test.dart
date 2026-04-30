import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator', () {
    group('calculateMargin', () {
      test('calculates margin correctly', () {
        final result = TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(result.buyTotal, equals(1010000));
        expect(result.sellNet, closeTo(1067000, 0.0001));
        expect(result.profit, closeTo(57000, 0.0001));
        expect(result.marginPercent, closeTo(5.6435643564, 0.0001));
        expect(result.brokerFee, equals(21000));
        expect(result.salesTax, equals(22000));
        expect(result.isProfitable, isTrue);
      });

      test('calculates break-even sell price', () {
        final result = TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(result, greaterThan(1010000));
        expect(result, closeTo(1041237.1134, 0.0001));
      });

      test('marks losing trades as not profitable', () {
        final result = TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1000000, // Selling at break-even price - should lose due to fees
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(result.profit, lessThan(0));
        expect(result.marginPercent, lessThan(0));
        expect(result.isProfitable, isFalse);
      });

      test('supports zero prices without producing NaN for totals', () {
        final result = TradeCalculator.calculateMargin(
          buyPrice: 0,
          sellPrice: 0,
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(result.buyTotal, equals(0));
        expect(result.sellNet, equals(0));
        expect(result.profit, equals(0));
        expect(result.marginPercent, equals(0));
        expect(result.brokerFee, equals(0));
        expect(result.salesTax, equals(0));
        expect(result.isProfitable, isFalse);
      });

      test('throws ArgumentError for invalid prices and fee percentages', () {
        // Test negative buy price
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: -1,
            sellPrice: 100,
            brokerFeePercent: 1.0,
            salesTaxPercent: 2.0,
          ),
          throwsA(predicate((e) => e is ArgumentError && e.message.contains('buyPrice'))),
        );

        // Test negative sell price
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: -1,
            brokerFeePercent: 1.0,
            salesTaxPercent: 2.0,
          ),
          throwsA(predicate((e) => e is ArgumentError && e.message.contains('sellPrice'))),
        );

        // Test negative broker fee
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 100,
            brokerFeePercent: -1.0,
            salesTaxPercent: 2.0,
          ),
          throwsA(predicate((e) => e is ArgumentError && e.message.contains('brokerFeePercent'))),
        );

        // Test negative sales tax
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 100,
            brokerFeePercent: 1.0,
            salesTaxPercent: -1.0,
          ),
          throwsA(predicate((e) => e is ArgumentError && e.message.contains('salesTaxPercent'))),
        );

        // Test total fees and taxes >= 100%
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 100,
            brokerFeePercent: 50.0,
            salesTaxPercent: 50.0,
          ),
          throwsA(predicate((e) => e is ArgumentError && e.message.contains('Total fees and taxes'))),
        );

        // Test breakEvenSellPrice negative buy price
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: -1,
            brokerFeePercent: 1.0,
            salesTaxPercent: 2.0,
          ),
          throwsA(predicate((e) => e is ArgumentError && e.message.contains('buyPrice'))),
        );

        // Test breakEvenSellPrice negative broker fee
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 100,
            brokerFeePercent: -1.0,
            salesTaxPercent: 2.0,
          ),
          throwsA(predicate((e) => e is ArgumentError && e.message.contains('brokerFeePercent'))),
        );

        // Test breakEvenSellPrice negative sales tax
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 100,
            brokerFeePercent: 1.0,
            salesTaxPercent: -1.0,
          ),
          throwsA(predicate((e) => e is ArgumentError && e.message.contains('salesTaxPercent'))),
        );

        // Test breakEvenSellPrice total fees and taxes >= 100%
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 100,
            brokerFeePercent: 50.0,
            salesTaxPercent: 50.0,
          ),
          throwsA(predicate((e) => e is ArgumentError && e.message.contains('Total fees and taxes'))),
        );
      });
    });

    group('breakEvenSellPrice', () {
      test('calculates correct break-even price', () {
        final result = TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(result, greaterThan(1010000));
        expect(result, closeTo(1041237.1134, 0.0001));
      });
    });
  });
}