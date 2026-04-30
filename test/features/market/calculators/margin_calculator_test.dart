import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('calculates margin correctly', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1100000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(margin.buyPrice, 1000000);
      expect(margin.sellPrice, 1100000);
      expect(margin.buyTotal, 1010000);
      expect(margin.sellNet, 1067000);
      expect(margin.profit, 57000);
      expect(margin.marginPercent, closeTo(5.643564356, 0.0000001));
      expect(margin.brokerFee, 21000);
      expect(margin.salesTax, 22000);
      expect(margin.isProfitable, isTrue);
    });

    test('identifies an unprofitable trade', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1000000,
      );

      expect(margin.buyTotal, 1010000);
      expect(margin.sellNet, 970000);
      expect(margin.profit, -40000);
      expect(margin.isProfitable, isFalse);
    });

    test('returns zero values for zero buy and sell prices', () {
      final margin = TradeCalculator.calculateMargin(
        buyPrice: 0,
        sellPrice: 0,
      );

      expect(margin.buyTotal, 0);
      expect(margin.sellNet, 0);
      expect(margin.profit, 0);
      expect(margin.marginPercent, 0);
      expect(margin.brokerFee, 0);
      expect(margin.salesTax, 0);
      expect(margin.isProfitable, isFalse);
    });

    test('throws ArgumentError for invalid margin inputs', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: -1,
          sellPrice: 100,
        ),
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
          buyPrice: double.infinity,
          sellPrice: 100,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: -1,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: double.nan,
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
          brokerFeePercent: -1,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: double.nan,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: double.infinity,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          salesTaxPercent: -1,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          salesTaxPercent: double.nan,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          salesTaxPercent: double.infinity,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: 100.0,
          salesTaxPercent: 0.0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates break-even sell price', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result, closeTo(1041237.1134020619, 0.0000001));
      expect(result, greaterThan(1010000));
    });

    test('returns zero when buy price is zero', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 0,
      );

      expect(result, 0);
    });

    test('throws ArgumentError for invalid break-even inputs', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: -1,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: double.nan,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: double.infinity,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: -1,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: double.nan,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: double.infinity,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          salesTaxPercent: -1,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          salesTaxPercent: double.nan,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          salesTaxPercent: double.infinity,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: 100.0,
          salesTaxPercent: 0.0,
        ),
        throwsArgumentError,
      );
    });
  });
}
