import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('calculateMargin', () {
    test('calculates profitable trade without fees', () {
      final result = calculateMargin(
        buyPrice: 100,
        sellPrice: 125,
        quantity: 10,
      );

      expect(result.grossCost, 1000);
      expect(result.grossRevenue, 1250);
      expect(result.brokerFee, 0);
      expect(result.salesTax, 0);
      expect(result.netProfit, 250);
      expect(result.profitMarginPercent, 20);
      expect(result.returnOnInvestmentPercent, 25);
      expect(result.isProfitable, true);
    });

    test('subtracts broker fee and sales tax from profit', () {
      final result = calculateMargin(
        buyPrice: 100,
        sellPrice: 120,
        quantity: 5,
        brokerFeeRate: 0.03,
        salesTaxRate: 0.02,
      );

      expect(result.grossCost, 500);
      expect(result.grossRevenue, 600);
      expect(result.brokerFee, 18);
      expect(result.salesTax, 12);
      expect(result.netProfit, 70);
      expect(result.profitMarginPercent, closeTo(11.6666666667, 0.000001));
      expect(result.returnOnInvestmentPercent, closeTo(14, 0.000001));
      expect(result.isProfitable, true);
    });

    test('identifies losing trade', () {
      final result = calculateMargin(
        buyPrice: 100,
        sellPrice: 90,
        quantity: 3,
      );

      expect(result.netProfit, -30);
      expect(result.profitMarginPercent, closeTo(-11.1111111111, 0.000001));
      expect(result.returnOnInvestmentPercent, -10);
      expect(result.isProfitable, false);
    });

    test('returns zero percentages when revenue and cost are zero', () {
      final result = calculateMargin(
        buyPrice: 0,
        sellPrice: 0,
      );

      expect(result.grossCost, 0);
      expect(result.grossRevenue, 0);
      expect(result.netProfit, 0);
      expect(result.profitMarginPercent, 0);
      expect(result.returnOnInvestmentPercent, 0);
      expect(result.isProfitable, false);
    });

    test('throws ArgumentError for invalid numeric inputs', () {
      expect(
        () => calculateMargin(buyPrice: -1, sellPrice: 100),
        throwsArgumentError,
      );
      expect(
        () => calculateMargin(buyPrice: 100, sellPrice: -1),
        throwsArgumentError,
      );
      expect(
        () => calculateMargin(buyPrice: 100, sellPrice: 100, quantity: 0),
        throwsArgumentError,
      );
      expect(
        () => calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeeRate: -0.1,
        ),
        throwsArgumentError,
      );
      expect(
        () => calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          brokerFeeRate: 1.1,
        ),
        throwsArgumentError,
      );
      expect(
        () => calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          salesTaxRate: -0.1,
        ),
        throwsArgumentError,
      );
      expect(
        () => calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
          salesTaxRate: 1.1,
        ),
        throwsArgumentError,
      );
    });
  });
}
