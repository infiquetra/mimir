import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('calculateMargin', () {
    test('returns spec values with default fees', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 150.0,
      );

      expect(margin.buyTotal, closeTo(101.0, 0.0001));
      expect(margin.sellNet, closeTo(145.5, 0.0001));
      expect(margin.profit, closeTo(44.5, 0.0001));
      expect(margin.marginPercent, closeTo(44.05940594059406, 0.0001));
      expect(margin.brokerFee, closeTo(2.5, 0.0001));
      expect(margin.salesTax, closeTo(3.0, 0.0001));
      expect(margin.isProfitable, isTrue);
    });

    test('returns loss and negative margin when sell net is below buy total', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 90.0,
      );

      expect(margin.profit, lessThan(0.0));
      expect(margin.isProfitable, isFalse);
    });

    test('applies custom broker fee and sales tax percentages', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 200.0,
        sellPrice: 260.0,
        brokerFeePercent: 2.0,
        salesTaxPercent: 4.0,
      );

      expect(margin.buyTotal, closeTo(204.0, 0.0001));
      expect(margin.sellNet, closeTo(244.4, 0.0001));
      expect(margin.profit, closeTo(40.4, 0.0001));
      expect(margin.brokerFee, closeTo(9.2, 0.0001));
      expect(margin.salesTax, closeTo(10.4, 0.0001));
    });

    test('rejects non-positive buy price', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 0.0, sellPrice: 100.0),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: -1.0, sellPrice: 100.0),
        throwsArgumentError,
      );
    });

    test('rejects negative sell price', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 100.0, sellPrice: -1.0),
        throwsArgumentError,
      );
    });

    test('rejects negative broker fee percent', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 150.0,
          brokerFeePercent: -1.0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative sales tax percent', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 150.0,
          salesTaxPercent: -1.0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects fee and tax totals at or above 100 percent', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 150.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 150.0,
          brokerFeePercent: 51.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('breakEvenSellPrice', () {
    test('returns sell price where sell net equals buy total', () {
      final breakEven = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100.0,
      );

      expect(breakEven, closeTo(104.12371134020619, 0.0001));

      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: breakEven,
      );

      expect(margin.profit, closeTo(0.0, 0.0001));
    });

    test('rejects non-positive buy price', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: 0.0),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: -1.0),
        throwsArgumentError,
      );
    });

    test('rejects fee and tax totals at or above 100 percent', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: 51.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeMargin', () {
    test('isProfitable returns true when profit is positive', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 150.0,
      );

      expect(margin.isProfitable, isTrue);
    });

    test('isProfitable returns false when profit is negative', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 90.0,
      );

      expect(margin.isProfitable, isFalse);
    });
  });
}
