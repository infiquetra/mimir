import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('calculates profitable station trade margin with default fees', () {
      const buyPrice = 100.0;
      const sellPrice = 120.0;

      final result = TradeCalculator.calculateMargin(
        buyPrice: buyPrice,
        sellPrice: sellPrice,
      );

      expect(result.buyPrice, equals(buyPrice));
      expect(result.sellPrice, equals(sellPrice));
      expect(result.buyTotal, closeTo(101.0, 0.001));
      expect(result.sellNet, closeTo(116.4, 0.001));
      expect(result.profit, closeTo(15.4, 0.001));
      expect(result.marginPercent, closeTo(15.2475, 0.001));
      expect(result.brokerFee, closeTo(2.2, 0.001));
      expect(result.salesTax, closeTo(2.4, 0.001));
      expect(result.isProfitable, isTrue);
    });

    test('calculates unprofitable trade margin and marks it not profitable', () {
      const buyPrice = 100.0;
      const sellPrice = 101.0;

      final result = TradeCalculator.calculateMargin(
        buyPrice: buyPrice,
        sellPrice: sellPrice,
      );

      expect(result.buyPrice, equals(buyPrice));
      expect(result.sellPrice, equals(sellPrice));
      expect(result.buyTotal, closeTo(101.0, 0.001));
      expect(result.sellNet, closeTo(97.97, 0.001));
      expect(result.profit, closeTo(-3.03, 0.001));
      expect(result.marginPercent, closeTo(-3.0, 0.001));
      expect(result.brokerFee, closeTo(2.01, 0.001));
      expect(result.salesTax, closeTo(2.02, 0.001));
      expect(result.isProfitable, isFalse);
    });

    test('uses custom broker fee and sales tax percentages', () {
      const buyPrice = 50.0;
      const sellPrice = 75.0;
      const brokerFeePercent = 2.5;
      const salesTaxPercent = 5.0;

      final result = TradeCalculator.calculateMargin(
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        brokerFeePercent: brokerFeePercent,
        salesTaxPercent: salesTaxPercent,
      );

      expect(result.buyTotal, closeTo(51.25, 0.001));
      expect(result.sellNet, closeTo(69.375, 0.001));
      expect(result.profit, closeTo(18.125, 0.001));
      expect(result.brokerFee, closeTo(3.125, 0.001));
      expect(result.salesTax, closeTo(3.75, 0.001));
      expect(result.isProfitable, isTrue);
    });

    test('throws ArgumentError for invalid prices', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 0.0, sellPrice: 100.0),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: -1.0, sellPrice: 100.0),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 100.0, sellPrice: -1.0),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when combined fees make sell net impossible', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 100.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for negative broker fee', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 100.0,
          brokerFeePercent: -1.0,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for negative sales tax', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 100.0,
          salesTaxPercent: -1.0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates break-even sell price with default fees', () {
      const buyPrice = 100.0;

      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: buyPrice,
      );

      // buyTotal = 100 * 1.01 = 101
      // den = 1 - 0.01 - 0.02 = 0.97
      // breakEven = 101 / 0.97 ≈ 104.1237
      expect(result, closeTo(104.1237, 0.001));
    });

    test('calculates break-even sell price with custom fees', () {
      const buyPrice = 200.0;
      const brokerFeePercent = 2.0;
      const salesTaxPercent = 3.0;

      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: buyPrice,
        brokerFeePercent: brokerFeePercent,
        salesTaxPercent: salesTaxPercent,
      );

      // buyTotal = 200 * 1.02 = 204
      // den = 1 - 0.02 - 0.03 = 0.95
      // breakEven = 204 / 0.95 ≈ 214.7368
      expect(result, closeTo(214.7368, 0.001));
    });

    test('throws ArgumentError for invalid inputs', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: 0.0),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: -1.0),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when combined fees make denominator non-positive', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: 60.0,
          salesTaxPercent: 40.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: 100.0,
          salesTaxPercent: 0.0,
        ),
        throwsArgumentError,
      );
    });
  });
}
