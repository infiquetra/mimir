import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('MarginCalculator.calculateMargin', () {
    test('calculates margin correctly', () {
      final result = MarginCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1100000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result.buyTotal, 1010000);
      expect(result.sellNet, closeTo(1067000, 0.01));
      expect(result.profit, 57000);
      expect(result.marginPercent, closeTo(5.643564356435644, 1e-12));
      expect(result.brokerFee, 21000);
      expect(result.salesTax, 22000);
      expect(result.isProfitable, isTrue);
    });

    test('uses default broker fee and sales tax percentages', () {
      final result = MarginCalculator.calculateMargin(
        buyPrice: 100000,
        sellPrice: 110000,
      );

      // Default: 1 % broker fee, 2 % sales tax.
      // buyTotal = 100000 * (1 + 1/100) = 101000
      // sellNet = 110000 * (1 - 1/100 - 2/100) = 110000 * 0.97 = 106700
      expect(result.buyTotal, 101000);
      expect(result.sellNet, closeTo(106700, 0.01));
      expect(result.profit, closeTo(5700, 0.01));
    });

    test('marks loss and zero-profit trades as not profitable', () {
      // Loss trade: sell below buy
      final loss = MarginCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 900000,
      );
      expect(loss.isProfitable, isFalse);
      expect(loss.profit, lessThan(0));

      // Zero-profit trade: sell at break-even
      final zeroProfit = MarginCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: MarginCalculator.breakEvenSellPrice(buyPrice: 1000000),
      );
      expect(zeroProfit.isProfitable, isFalse);
      expect(zeroProfit.profit, closeTo(0, 0.01));
    });

    test('throws ArgumentError for non-positive buy price', () {
      expect(
        () => MarginCalculator.calculateMargin(buyPrice: 0, sellPrice: 1000000),
        throwsArgumentError,
      );

      expect(
        () => MarginCalculator.calculateMargin(
          buyPrice: -100,
          sellPrice: 1000000,
        ),
        throwsArgumentError,
      );
    });

    test(
      'throws ArgumentError when total sell-side fees are 100 percent or more',
      () {
        expect(
          () => MarginCalculator.calculateMargin(
            buyPrice: 1000000,
            sellPrice: 1100000,
            brokerFeePercent: 50,
            salesTaxPercent: 50,
          ),
          throwsArgumentError,
        );

        expect(
          () => MarginCalculator.calculateMargin(
            buyPrice: 1000000,
            sellPrice: 1100000,
            brokerFeePercent: 60,
            salesTaxPercent: 50,
          ),
          throwsArgumentError,
        );
      },
    );

    test('throws ArgumentError for negative sell price', () {
      expect(
        () =>
            MarginCalculator.calculateMargin(buyPrice: 1000000, sellPrice: -1),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for negative broker fee percent', () {
      expect(
        () => MarginCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: -1,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for negative sales tax percent', () {
      expect(
        () => MarginCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          salesTaxPercent: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('MarginCalculator.breakEvenSellPrice', () {
    test('calculates break-even sell price', () {
      final result = MarginCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result, closeTo(1041237.1134020619, 1e-10));
      expect(result, greaterThan(1010000));
    });

    test(
      'throws ArgumentError when total sell-side fees are 100 percent or more',
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
            brokerFeePercent: 60,
            salesTaxPercent: 50,
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
