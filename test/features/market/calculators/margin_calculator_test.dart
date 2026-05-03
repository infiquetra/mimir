import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeMargin', () {
    test('isProfitable returns true when profit is positive', () {
      const margin = TradeMargin(
        buyPrice: 100,
        sellPrice: 200,
        buyTotal: 101,
        sellNet: 194,
        profit: 93,
        marginPercent: 92.08,
        brokerFee: 4,
        salesTax: 4,
      );
      expect(margin.isProfitable, isTrue);
    });

    test('isProfitable returns false when profit is zero', () {
      const margin = TradeMargin(
        buyPrice: 100,
        sellPrice: 100,
        buyTotal: 100,
        sellNet: 100,
        profit: 0,
        marginPercent: 0,
        brokerFee: 0,
        salesTax: 0,
      );
      expect(margin.isProfitable, isFalse);
    });

    test('isProfitable returns false when profit is negative', () {
      const margin = TradeMargin(
        buyPrice: 100,
        sellPrice: 80,
        buyTotal: 101,
        sellNet: 77.6,
        profit: -23.4,
        marginPercent: -23.17,
        brokerFee: 1.8,
        salesTax: 1.6,
      );
      expect(margin.isProfitable, isFalse);
    });
  });

  group('TradeCalculator', () {
    group('calculateMargin', () {
      test('calculates margin correctly', () {
        const buyPrice = 1000000.0;
        const sellPrice = 1100000.0;
        const brokerFeePercent = 1.0;
        const salesTaxPercent = 2.0;

        final margin = TradeCalculator.calculateMargin(
          buyPrice: buyPrice,
          sellPrice: sellPrice,
          brokerFeePercent: brokerFeePercent,
          salesTaxPercent: salesTaxPercent,
        );

        expect(margin.buyPrice, 1000000);
        expect(margin.sellPrice, 1100000);
        expect(margin.buyTotal, 1010000);
        expect(margin.sellNet, closeTo(1067000, 0.01));
        expect(margin.profit, closeTo(57000, 0.01));
        expect(margin.marginPercent, closeTo(5.6435643564, 0.0001));
        expect(margin.brokerFee, 21000);
        expect(margin.salesTax, 22000);
        expect(margin.isProfitable, isTrue);
      });

      test('reports unprofitable margin when fees exceed spread', () {
        const buyPrice = 1000000.0;
        const sellPrice = 1010000.0;

        final margin = TradeCalculator.calculateMargin(
          buyPrice: buyPrice,
          sellPrice: sellPrice,
        );

        expect(margin.profit, lessThan(0));
        expect(margin.marginPercent, lessThan(0));
        expect(margin.isProfitable, isFalse);
      });

      test('handles zero buy and sell prices without NaN margin percent', () {
        final margin = TradeCalculator.calculateMargin(
          buyPrice: 0,
          sellPrice: 0,
        );

        expect(margin.buyPrice, 0);
        expect(margin.sellPrice, 0);
        expect(margin.buyTotal, 0);
        expect(margin.sellNet, 0);
        expect(margin.profit, 0);
        expect(margin.marginPercent, 0);
        expect(margin.brokerFee, 0);
        expect(margin.salesTax, 0);
        expect(margin.isProfitable, isFalse);
      });

      test('rejects negative and non-finite inputs', () {
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
      });

      test('rejects negative fee rates', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 200,
            brokerFeePercent: -1,
          ),
          throwsArgumentError,
        );
      });

      test('rejects impossible sell-side fee combinations', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 200,
            brokerFeePercent: 50,
            salesTaxPercent: 50,
          ),
          throwsArgumentError,
        );
      });
    });

    group('breakEvenSellPrice', () {
      test('calculates break-even sell price', () {
        const buyPrice = 1000000.0;
        const brokerFeePercent = 1.0;
        const salesTaxPercent = 2.0;

        final result = TradeCalculator.breakEvenSellPrice(
          buyPrice: buyPrice,
          brokerFeePercent: brokerFeePercent,
          salesTaxPercent: salesTaxPercent,
        );

        // 1,010,000 / 0.97 = 1,041,237.113402...
        expect(result, closeTo(1041237.1134, 0.01));
        expect(result, greaterThan(1010000));
      });

      test('handles zero buy price', () {
        final result = TradeCalculator.breakEvenSellPrice(
          buyPrice: 0,
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(result, 0);
      });

      test('rejects negative and non-finite buyPrice', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(buyPrice: -1),
          throwsArgumentError,
        );

        expect(
          () => TradeCalculator.breakEvenSellPrice(buyPrice: double.nan),
          throwsArgumentError,
        );
      });

      test('rejects impossible sell-side fees', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 100,
            brokerFeePercent: 50,
            salesTaxPercent: 50,
          ),
          throwsArgumentError,
        );
      });
    });
  });
}
