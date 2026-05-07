import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('calculates profitable station trade margin with default fees', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
      );

      expect(result.buyTotal, closeTo(101.0, 0.000001));
      expect(result.sellNet, closeTo(116.4, 0.000001));
      expect(result.profit, closeTo(15.4, 0.000001));
      expect(result.marginPercent, closeTo(15.2475247525, 0.000001));
      expect(result.brokerFee, closeTo(2.2, 0.000001));
      expect(result.salesTax, closeTo(2.4, 0.000001));
      expect(result.isProfitable, true);
    });

    test('calculates loss-making margin as not profitable', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 100.0,
      );

      expect(result.buyTotal, closeTo(101.0, 0.000001));
      expect(result.sellNet, closeTo(97.0, 0.000001));
      expect(result.profit, closeTo(-4.0, 0.000001));
      expect(result.marginPercent, closeTo(-3.9603960396, 0.000001));
      expect(result.brokerFee, closeTo(2.0, 0.000001));
      expect(result.salesTax, closeTo(2.0, 0.000001));
      expect(result.isProfitable, false);
    });

    test('uses custom broker fee and sales tax percentages', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000000.0,
        sellPrice: 1250000.0,
        brokerFeePercent: 0.5,
        salesTaxPercent: 1.5,
      );

      expect(result.buyTotal, closeTo(1005000.0, 0.000001));
      expect(result.sellNet, closeTo(1225000.0, 0.000001));
      expect(result.profit, closeTo(220000.0, 0.000001));
      expect(result.marginPercent, closeTo(21.8905472637, 0.000001));
      expect(result.brokerFee, closeTo(11250.0, 0.000001));
      expect(result.salesTax, closeTo(18750.0, 0.000001));
      expect(result.isProfitable, true);
    });

    test('throws ArgumentError for invalid prices', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 0.0, sellPrice: 120.0),
        throwsArgumentError,
      );

      expect(
        () =>
            TradeCalculator.calculateMargin(buyPrice: -50.0, sellPrice: 120.0),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 100.0, sellPrice: 0.0),
        throwsArgumentError,
      );

      expect(
        () =>
            TradeCalculator.calculateMargin(buyPrice: 100.0, sellPrice: -10.0),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.nan,
          sellPrice: 120.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: double.infinity,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for invalid fee percentages', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          brokerFeePercent: -1.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          salesTaxPercent: -0.5,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: 120.0,
          brokerFeePercent: 100.0,
          salesTaxPercent: 0.0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates break-even sell price with default fees', () {
      // buyTotal = 100 * 1.01 = 101; 101 / 0.97 ≈ 104.1237113402
      final result = TradeCalculator.breakEvenSellPrice(buyPrice: 100.0);

      expect(result, closeTo(104.1237113402, 0.000001));
    });

    test('calculates break-even sell price with custom fees', () {
      // buyTotal = 1000000 * 1.005 = 1005000; 1005000 / 0.98 = 1025510.2040816326...
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000.0,
        brokerFeePercent: 0.5,
        salesTaxPercent: 1.5,
      );

      expect(result, closeTo(1025510.2040816326, 0.000001));
    });

    test('throws ArgumentError when deductions make break-even impossible', () {
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
          brokerFeePercent: 100.0,
          salesTaxPercent: 0.0,
        ),
        throwsArgumentError,
      );
    });
  });
}
