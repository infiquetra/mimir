import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('calculates profitable default-fee margin', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: 150,
      );

      expect(result.buyPrice, closeTo(100.0, 1e-9));
      expect(result.sellPrice, closeTo(150.0, 1e-9));
      expect(result.buyTotal, closeTo(101.0, 1e-9));
      expect(result.sellNet, closeTo(145.5, 1e-9));
      expect(result.profit, closeTo(44.5, 1e-9));
      expect(result.marginPercent, closeTo(44.05940594059406, 1e-9));
      expect(result.brokerFee, closeTo(2.5, 1e-9));
      expect(result.salesTax, closeTo(3.0, 1e-9));
      expect(result.isProfitable, true);
    });

    test('reports losses after fees when sell price matches buy price', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: 100,
      );

      expect(result.profit, closeTo(-4.0, 1e-9));
      expect(result.marginPercent, closeTo(-3.96039603960396, 1e-9));
      expect(result.isProfitable, false);
    });

    test('supports zero fees and taxes', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: 150,
        brokerFeePercent: 0,
        salesTaxPercent: 0,
      );

      expect(result.buyTotal, 100.0);
      expect(result.sellNet, 150.0);
      expect(result.profit, 50.0);
      expect(result.marginPercent, 50.0);
      expect(result.brokerFee, 0.0);
      expect(result.salesTax, 0.0);
    });

    test('supports custom broker fee and sales tax', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100,
        sellPrice: 150,
        brokerFeePercent: 3,
        salesTaxPercent: 5,
      );

      expect(result.buyTotal, closeTo(103.0, 1e-9));
      expect(result.sellNet, closeTo(138.0, 1e-9));
      expect(result.profit, closeTo(35.0, 1e-9));
      expect(result.marginPercent, closeTo(33.98058252427184, 1e-9));
      expect(result.brokerFee, closeTo(7.5, 1e-9));
      expect(result.salesTax, closeTo(7.5, 1e-9));
    });

    test('returns zero margin percent for zero buy total', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 0,
        sellPrice: 100,
        brokerFeePercent: 1,
        salesTaxPercent: 2,
      );

      // No NaN / infinity in any field.
      expect(result.buyTotal, 0.0);
      expect(result.marginPercent, 0.0);
      expect(result.profit.isNaN, false);
      expect(result.profit.isInfinite, false);
    });

    test('throws ArgumentError for invalid prices or fees', () {
      // negative buyPrice
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: -1,
          sellPrice: 100,
        ),
        throwsArgumentError,
      );

      // negative sellPrice
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: -1,
        ),
        throwsArgumentError,
      );

      // NaN buyPrice
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.nan,
          sellPrice: 100,
        ),
        throwsArgumentError,
      );

      // NaN sellPrice
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: double.nan,
        ),
        throwsArgumentError,
      );

      // negative brokerFeePercent
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: -1,
        ),
        throwsArgumentError,
      );

      // negative salesTaxPercent
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          salesTaxPercent: -1,
        ),
        throwsArgumentError,
      );

      // combined fee/tax >= 100%
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: 50,
          salesTaxPercent: 50,
        ),
        throwsArgumentError,
      );

      // combined fee/tax > 100%
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeePercent: 60,
          salesTaxPercent: 50,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates default-fee break-even sell price', () {
      final result = TradeCalculator.breakEvenSellPrice(buyPrice: 100);

      expect(result, closeTo(104.12371134020619, 1e-9));
    });

    test('returns buy price when fees and taxes are zero', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100,
        brokerFeePercent: 0,
        salesTaxPercent: 0,
      );

      expect(result, 100.0);
    });

    test('supports custom fee break-even sell price', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100,
        brokerFeePercent: 3,
        salesTaxPercent: 5,
      );

      expect(result, closeTo(111.95652173913044, 1e-9));
    });

    test(
      'throws ArgumentError when combined fees leave no net sell proceeds',
      () {
        // exactly 100%
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 100,
            brokerFeePercent: 50,
            salesTaxPercent: 50,
          ),
          throwsArgumentError,
        );

        // above 100%
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 100,
            brokerFeePercent: 60,
            salesTaxPercent: 50,
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
