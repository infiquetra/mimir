import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('calculateMargin', () {
    test(
        'calculates profit, margin, roi, and fees for a profitable trade',
        () {
      const input = MarginCalculationInput(
        buyPrice: 100,
        sellPrice: 150,
        quantity: 10,
        brokerFeeRate: 0.03,
        salesTaxRate: 0.08,
      );

      final result = calculateMargin(input);

      expect(result.totalCost, 1000);
      expect(result.grossRevenue, 1500);
      expect(result.brokerFees, 45);
      expect(result.salesTax, 120);
      expect(result.netRevenue, 1335);
      expect(result.profit, 335);
      expect(result.profitPerUnit, 33.5);
      expect(result.marginPercent, closeTo(22.3333333333, 0.000001));
      expect(result.returnOnInvestmentPercent, 33.5);
      expect(result.breakEvenSellPrice,
          closeTo(112.3595505618, 0.000001));
      expect(result.isProfitable, isTrue);
    });

    test('reports a loss when fees and sell price exceed proceeds',
        () {
      const input = MarginCalculationInput(
        buyPrice: 100,
        sellPrice: 90,
        quantity: 2,
        brokerFeeRate: 0.05,
        salesTaxRate: 0.05,
      );

      final result = calculateMargin(input);

      expect(result.grossRevenue, 180);
      expect(result.brokerFees, 9);
      expect(result.salesTax, 9);
      expect(result.netRevenue, 162);
      expect(result.profit, -38);
      expect(result.profitPerUnit, -19);
      expect(result.marginPercent, closeTo(-21.1111111111, 0.000001));
      expect(result.returnOnInvestmentPercent, -19);
      expect(result.isProfitable, isFalse);
    });

    test(
        'calculates zero profit at the fee-adjusted break-even sell price',
        () {
      const buyPrice = 100.0;
      const brokerFeeRate = 0.03;
      const salesTaxRate = 0.08;
      const sellPrice = buyPrice / (1 - brokerFeeRate - salesTaxRate);

      const input = MarginCalculationInput(
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        quantity: 5,
        brokerFeeRate: brokerFeeRate,
        salesTaxRate: salesTaxRate,
      );

      final result = calculateMargin(input);

      expect(result.breakEvenSellPrice, closeTo(sellPrice, 0.000001));
      expect(result.profit, closeTo(0, 0.000001));
      expect(result.marginPercent, closeTo(0, 0.000001));
      expect(result.returnOnInvestmentPercent, closeTo(0, 0.000001));
      expect(result.isProfitable, isFalse);
    });

    group('validation', () {
      test('throws ArgumentError for invalid prices and quantity',
          () {
        expect(
          () => calculateMargin(
            const MarginCalculationInput(
              buyPrice: 0,
              sellPrice: 100,
              quantity: 1,
            ),
          ),
          throwsArgumentError,
        );

        expect(
          () => calculateMargin(
            const MarginCalculationInput(
              buyPrice: 1,
              sellPrice: -1,
              quantity: 1,
            ),
          ),
          throwsArgumentError,
        );

        expect(
          () => calculateMargin(
            const MarginCalculationInput(
              buyPrice: 1,
              sellPrice: 100,
              quantity: 0,
            ),
          ),
          throwsArgumentError,
        );
      });

      test('throws ArgumentError for invalid fee and tax rates',
          () {
        expect(
          () => calculateMargin(
            const MarginCalculationInput(
              buyPrice: 1,
              sellPrice: 100,
              quantity: 1,
              brokerFeeRate: -0.01,
            ),
          ),
          throwsArgumentError,
        );

        expect(
          () => calculateMargin(
            const MarginCalculationInput(
              buyPrice: 1,
              sellPrice: 100,
              quantity: 1,
              brokerFeeRate: 1,
            ),
          ),
          throwsArgumentError,
        );

        expect(
          () => calculateMargin(
            const MarginCalculationInput(
              buyPrice: 1,
              sellPrice: 100,
              quantity: 1,
              salesTaxRate: -0.01,
            ),
          ),
          throwsArgumentError,
        );

        expect(
          () => calculateMargin(
            const MarginCalculationInput(
              buyPrice: 1,
              sellPrice: 100,
              quantity: 1,
              salesTaxRate: 1,
            ),
          ),
          throwsArgumentError,
        );

        expect(
          () => calculateMargin(
            const MarginCalculationInput(
              buyPrice: 1,
              sellPrice: 100,
              quantity: 1,
              brokerFeeRate: 0.6,
              salesTaxRate: 0.4,
            ),
          ),
          throwsArgumentError,
        );
      });
    });
  });
}
