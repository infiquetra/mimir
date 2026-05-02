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

        expect(result.buyPrice, 1000000);
        expect(result.sellPrice, 1100000);
        expect(result.buyTotal, 1010000);
        expect(result.sellNet, closeTo(1067000, 0.001));
        expect(result.profit, closeTo(57000, 0.001));
        expect(result.marginPercent, closeTo(5.643564356435644, 0.001));
        expect(result.brokerFee, 21000);
        expect(result.salesTax, 22000);
        expect(result.isProfitable, isTrue);
      });

      test('marks negative profit margins as not profitable', () {
        final result = TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 900000,
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(result.profit, lessThan(0));
        expect(result.isProfitable, isFalse);
        expect(result.marginPercent, lessThan(0));
      });

      test('uses default broker fee and sales tax percentages', () {
        final result = TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
        );

        expect(result.buyTotal, 1010000);
        expect(result.sellNet, closeTo(1067000, 0.001));
        expect(result.brokerFee, 21000);
        expect(result.salesTax, 22000);
      });

      test('handles zero buy price without dividing by zero', () {
        final result = TradeCalculator.calculateMargin(
          buyPrice: 0,
          sellPrice: 1000,
        );

        expect(result.buyTotal, 0);
        expect(result.sellNet, closeTo(970, 0.001));
        expect(result.profit, closeTo(970, 0.001));
        expect(result.marginPercent, 0);
        expect(result.isProfitable, isTrue);
      });

      test('throws ArgumentError for negative buyPrice', () {
        expect(
          () => TradeCalculator.calculateMargin(buyPrice: -1, sellPrice: 1000),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for negative sellPrice', () {
        expect(
          () => TradeCalculator.calculateMargin(buyPrice: 1000, sellPrice: -1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for negative brokerFeePercent', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 1000,
            sellPrice: 1100,
            brokerFeePercent: -0.1,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for negative salesTaxPercent', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 1000,
            sellPrice: 1100,
            salesTaxPercent: -0.1,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
        'throws ArgumentError when sell fees are 100 percent or greater',
        () {
          expect(
            () => TradeCalculator.calculateMargin(
              buyPrice: 1000,
              sellPrice: 1100,
              brokerFeePercent: 60,
              salesTaxPercent: 40,
            ),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      test('throws ArgumentError when sell fees exceed 100 percent', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 1000,
            sellPrice: 1100,
            brokerFeePercent: 60,
            salesTaxPercent: 50,
          ),
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
        expect(result, closeTo(1041237.1134020619, 0.001));
      });

      test('uses default broker fee and sales tax percentages', () {
        final result = TradeCalculator.breakEvenSellPrice(buyPrice: 1000000);

        expect(result, closeTo(1041237.1134020619, 0.001));
      });

      test('returns buyPrice when fees are zero', () {
        final result = TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: 0,
          salesTaxPercent: 0,
        );

        expect(result, 1000000);
      });

      test('handles zero buy price', () {
        final result = TradeCalculator.breakEvenSellPrice(buyPrice: 0);

        expect(result, 0);
      });

      test('throws ArgumentError for negative buyPrice', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(buyPrice: -1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for negative brokerFeePercent', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 1000,
            brokerFeePercent: -0.1,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for negative salesTaxPercent', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 1000,
            salesTaxPercent: -0.1,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
        'throws ArgumentError when sell fees are 100 percent or greater',
        () {
          expect(
            () => TradeCalculator.breakEvenSellPrice(
              buyPrice: 1000,
              brokerFeePercent: 60,
              salesTaxPercent: 40,
            ),
            throwsA(isA<ArgumentError>()),
          );
        },
      );
    });
  });

  group('TradeMargin', () {
    test('isProfitable is true when profit is positive', () {
      const margin = TradeMargin(
        buyPrice: 100,
        sellPrice: 120,
        buyTotal: 101,
        sellNet: 116.4,
        profit: 15.4,
        marginPercent: 15.247,
        brokerFee: 3.2,
        salesTax: 2.4,
      );

      expect(margin.isProfitable, isTrue);
    });

    test('isProfitable is false when profit is negative', () {
      const margin = TradeMargin(
        buyPrice: 100,
        sellPrice: 80,
        buyTotal: 101,
        sellNet: 77.6,
        profit: -23.4,
        marginPercent: -23.168,
        brokerFee: 2.8,
        salesTax: 1.6,
      );

      expect(margin.isProfitable, isFalse);
    });

    test('isProfitable is false when profit is exactly zero', () {
      const margin = TradeMargin(
        buyPrice: 100,
        sellPrice: 104.1237,
        buyTotal: 101,
        sellNet: 101,
        profit: 0,
        marginPercent: 0,
        brokerFee: 2.04,
        salesTax: 2.08,
      );

      expect(margin.isProfitable, isFalse);
    });
  });
}
