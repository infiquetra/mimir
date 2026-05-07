import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator', () {
    group('calculateMargin', () {
      test('calculates margin correctly', () {
        final margin = TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(margin.buyTotal, equals(1010000));
        expect(margin.sellNet, closeTo(1067000, 1));
        expect(margin.profit, closeTo(57000, 1));
        expect(margin.marginPercent, closeTo(5.6435643564, 0.01));
        expect(margin.brokerFee, equals(21000));
        expect(margin.salesTax, equals(22000));
        expect(margin.isProfitable, isTrue);
      });

      test('uses default EVE fee percentages', () {
        final margin = TradeCalculator.calculateMargin(
          buyPrice: 1000,
          sellPrice: 1100,
        );

        // Default broker fee is 1%, default sales tax is 2%
        expect(margin.buyTotal, equals(1010));
        expect(margin.sellNet, closeTo(1067, 1));
        expect(margin.brokerFee, equals(21));
        expect(margin.salesTax, equals(22));
      });

      test('marks loss-making trades as not profitable', () {
        final margin = TradeCalculator.calculateMargin(
          buyPrice: 1000,
          sellPrice: 900,
        );

        expect(margin.profit, lessThan(0));
        expect(margin.isProfitable, isFalse);
      });

      test('returns zero margin percent for zero buy and sell prices', () {
        final margin = TradeCalculator.calculateMargin(
          buyPrice: 0,
          sellPrice: 0,
        );

        expect(margin.buyTotal, equals(0));
        expect(margin.sellNet, equals(0));
        expect(margin.profit, equals(0));
        expect(margin.marginPercent, equals(0));
        expect(margin.isProfitable, isFalse);
      });

      test('throws for negative or non-finite values', () {
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
            buyPrice: double.nan,
            sellPrice: 100,
          ),
          throwsArgumentError,
        );
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: double.infinity,
          ),
          throwsArgumentError,
        );
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 100,
            brokerFeePercent: -0.5,
          ),
          throwsArgumentError,
        );
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 100,
            salesTaxPercent: -1.0,
          ),
          throwsArgumentError,
        );
      });

      test(
        'throws when combined sell-side fees are 100 percent or more',
        () {
          expect(
            () => TradeCalculator.calculateMargin(
              buyPrice: 100,
              sellPrice: 200,
              brokerFeePercent: 50,
              salesTaxPercent: 50,
            ),
            throwsArgumentError,
          );
          expect(
            () => TradeCalculator.calculateMargin(
              buyPrice: 100,
              sellPrice: 200,
              brokerFeePercent: 60,
              salesTaxPercent: 50,
            ),
            throwsArgumentError,
          );
        },
      );
    });

    group('breakEvenSellPrice', () {
      test('calculates break-even sell price', () {
        final breakEven = TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(breakEven, closeTo(1041237.1134, 1));
        expect(breakEven, greaterThan(1010000));
      });

      test('uses default fees for break-even calculation', () {
        final breakEven = TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000,
        );

        // With default 1% broker, 2% tax: breakEven = 1010 / (1 - 0.01 - 0.02) = 1010 / 0.97
        expect(breakEven, closeTo(1041.237, 0.5));
      });

      test('throws for negative or non-finite inputs', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(buyPrice: -1),
          throwsArgumentError,
        );
        expect(
          () => TradeCalculator.breakEvenSellPrice(buyPrice: double.nan),
          throwsArgumentError,
        );
        expect(
          () => TradeCalculator.breakEvenSellPrice(
              buyPrice: 100, brokerFeePercent: -1),
          throwsArgumentError,
        );
        expect(
          () => TradeCalculator.breakEvenSellPrice(
              buyPrice: 100, salesTaxPercent: -1),
          throwsArgumentError,
        );
      });

      test('throws when combined fees are 100 percent or more', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 100,
            brokerFeePercent: 50,
            salesTaxPercent: 50,
          ),
          throwsArgumentError,
        );
      });

      test('returns buy price for zero fees', () {
        final breakEven = TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000,
          brokerFeePercent: 0,
          salesTaxPercent: 0,
        );

        expect(breakEven, equals(1000));
      });
    });
  });
}
