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

        expect(result.buyTotal, 1010000);
        expect(result.sellNet, closeTo(1067000, 0.01));
        expect(result.profit, closeTo(57000, 0.01));
        expect(result.marginPercent, closeTo(5.6435643564, 0.0001));
        expect(result.brokerFee, 21000);
        expect(result.salesTax, 22000);
        expect(result.isProfitable, true);
      });

      test('reports unprofitable trade', () {
        final result = TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1000000,
        );

        expect(result.profit, lessThan(0));
        expect(result.marginPercent, lessThan(0));
        expect(result.isProfitable, false);
      });

      test('handles zero buy price without dividing by zero', () {
        final result = TradeCalculator.calculateMargin(
          buyPrice: 0,
          sellPrice: 1100000,
        );

        expect(result.buyTotal, 0);
        expect(result.profit, result.sellNet);
        expect(result.marginPercent, 0);
      });

      test(
          'throws ArgumentError for negative prices or fees',
          () {
        expect(
          () => TradeCalculator.calculateMargin(
              buyPrice: -1, sellPrice: 100),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => TradeCalculator.calculateMargin(
              buyPrice: 100, sellPrice: -1),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => TradeCalculator.calculateMargin(
              buyPrice: 100, sellPrice: 100, brokerFeePercent: -1),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => TradeCalculator.calculateMargin(
              buyPrice: 100, sellPrice: 100, salesTaxPercent: -1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
          'throws ArgumentError when sell-side deductions are 100 percent or more',
          () {
        expect(
          () => TradeCalculator.calculateMargin(
              buyPrice: 100,
              sellPrice: 100,
              brokerFeePercent: 50,
              salesTaxPercent: 50),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => TradeCalculator.calculateMargin(
              buyPrice: 100,
              sellPrice: 100,
              brokerFeePercent: 60,
              salesTaxPercent: 50),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('breakEvenSellPrice', () {
      test('calculates break-even sell price', () {
        final result = TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(result, greaterThan(1010000));
        expect(result, closeTo(1041237.1134, 0.01));
      });

      test('returns zero for zero buy price', () {
        final result = TradeCalculator.breakEvenSellPrice(buyPrice: 0);
        expect(result, 0);
      });

      test('throws ArgumentError for invalid inputs', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(buyPrice: -1),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => TradeCalculator.breakEvenSellPrice(
              buyPrice: 100, brokerFeePercent: -1),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => TradeCalculator.breakEvenSellPrice(
              buyPrice: 100, salesTaxPercent: -1),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => TradeCalculator.breakEvenSellPrice(
              buyPrice: 100, brokerFeePercent: 50, salesTaxPercent: 50),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
