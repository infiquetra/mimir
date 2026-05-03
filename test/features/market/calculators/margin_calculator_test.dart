import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('MarginCalculator', () {
    group('calculateMargin', () {
      test('calculates margin correctly', () {
        final margin = MarginCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(margin.buyPrice, 1000000);
        expect(margin.sellPrice, 1100000);
        expect(margin.buyTotal, 1010000);
        expect(margin.sellNet, closeTo(1067000, 0.001));
        expect(margin.profit, closeTo(57000, 0.001));
        expect(margin.marginPercent, closeTo(5.6435643564, 0.000001));
        expect(margin.brokerFee, 21000);
        expect(margin.salesTax, 22000);
        expect(margin.isProfitable, isTrue);
      });

      test('marks losing trades as not profitable', () {
        final margin = MarginCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1000000,
        );

        expect(margin.profit, lessThan(0));
        expect(margin.marginPercent, lessThan(0));
        expect(margin.isProfitable, isFalse);
      });

      test('returns zero margin percent when buy total is zero', () {
        final margin = MarginCalculator.calculateMargin(
          buyPrice: 0,
          sellPrice: 100,
        );

        expect(margin.buyTotal, 0);
        expect(margin.sellNet, 97);
        expect(margin.profit, 97);
        expect(margin.marginPercent, 0);
      });

      test(
        'calculates margin when combined sell fees are at least 100 percent',
        () {
          // Exactly 100% combined fees: sellNet = 0
          final margin100 = MarginCalculator.calculateMargin(
            buyPrice: 1000000,
            sellPrice: 1000000,
            brokerFeePercent: 50,
            salesTaxPercent: 50,
          );

          expect(margin100.sellNet, 0);
          expect(margin100.profit, -1500000);
          expect(margin100.isProfitable, isFalse);

          // Above 100% combined fees: sellNet is negative
          final margin150 = MarginCalculator.calculateMargin(
            buyPrice: 1000000,
            sellPrice: 1000000,
            brokerFeePercent: 75,
            salesTaxPercent: 75,
          );

          expect(margin150.sellNet, -500000);
          expect(margin150.profit, -2250000);
          expect(margin150.isProfitable, isFalse);
        },
      );
    });

    group('breakEvenSellPrice', () {
      test('calculates break-even sell price', () {
        final breakEven = MarginCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(breakEven, greaterThan(1010000));
        expect(breakEven, closeTo(1041237.1134, 0.001));
      });
    });

    group('validation', () {
      test('rejects negative prices and fees', () {
        // calculateMargin negative inputs
        expect(
          () => MarginCalculator.calculateMargin(
            buyPrice: -1,
            sellPrice: 100,
          ),
          throwsArgumentError,
        );
        expect(
          () => MarginCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: -1,
          ),
          throwsArgumentError,
        );
        expect(
          () => MarginCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 100,
            brokerFeePercent: -0.1,
          ),
          throwsArgumentError,
        );
        expect(
          () => MarginCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 100,
            salesTaxPercent: -0.1,
          ),
          throwsArgumentError,
        );

        // breakEvenSellPrice negative inputs
        expect(
          () => MarginCalculator.breakEvenSellPrice(
            buyPrice: -1,
          ),
          throwsArgumentError,
        );
        expect(
          () => MarginCalculator.breakEvenSellPrice(
            buyPrice: 100,
            brokerFeePercent: -0.1,
          ),
          throwsArgumentError,
        );
        expect(
          () => MarginCalculator.breakEvenSellPrice(
            buyPrice: 100,
            salesTaxPercent: -0.1,
          ),
          throwsArgumentError,
        );
      });

      test('rejects non-finite values', () {
        // calculateMargin NaN and infinity
        expect(
          () => MarginCalculator.calculateMargin(
            buyPrice: double.nan,
            sellPrice: 100,
          ),
          throwsArgumentError,
        );
        expect(
          () => MarginCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: double.nan,
          ),
          throwsArgumentError,
        );
        expect(
          () => MarginCalculator.calculateMargin(
            buyPrice: double.infinity,
            sellPrice: 100,
          ),
          throwsArgumentError,
        );
        expect(
          () => MarginCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: double.infinity,
          ),
          throwsArgumentError,
        );

        // breakEvenSellPrice NaN and infinity
        expect(
          () => MarginCalculator.breakEvenSellPrice(
            buyPrice: double.nan,
          ),
          throwsArgumentError,
        );
        expect(
          () => MarginCalculator.breakEvenSellPrice(
            buyPrice: double.infinity,
          ),
          throwsArgumentError,
        );
      });

      test(
        'rejects combined sell fees of 100 percent or more for break-even only',
        () {
          expect(
            () => MarginCalculator.breakEvenSellPrice(
              buyPrice: 1000000,
              brokerFeePercent: 50,
              salesTaxPercent: 50,
            ),
            throwsArgumentError,
          );
          expect(
            () => MarginCalculator.breakEvenSellPrice(
              buyPrice: 1000000,
              brokerFeePercent: 75,
              salesTaxPercent: 75,
            ),
            throwsArgumentError,
          );
        },
      );
    });
  });
}
