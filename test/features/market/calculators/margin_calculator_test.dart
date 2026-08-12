import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('calculates default station-trading margin from the blueprint formula', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
      );

      expect(result.buyPrice, closeTo(100.0, 1e-9));
      expect(result.sellPrice, closeTo(120.0, 1e-9));
      expect(result.buyTotal, closeTo(101.0, 1e-9));
      expect(result.sellNet, closeTo(116.4, 1e-9));
      expect(result.profit, closeTo(15.4, 1e-9));
      expect(result.marginPercent, closeTo(15.247524752475247, 1e-9));
      expect(result.brokerFee, closeTo(2.2, 1e-9));
      expect(result.salesTax, closeTo(2.4, 1e-9));
      expect(result.isProfitable, isTrue);
    });

    test('uses custom broker fee and sales tax percentages', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 130.0,
        brokerFeePercent: 2.0,
        salesTaxPercent: 5.0,
      );

      expect(result.buyTotal, closeTo(102.0, 1e-9));
      expect(result.sellNet, closeTo(120.9, 1e-9));
      expect(result.profit, closeTo(18.9, 1e-9));
      expect(result.marginPercent, closeTo(18.529411764705884, 1e-9));
      expect(result.brokerFee, closeTo(4.6, 1e-9));
      expect(result.salesTax, closeTo(6.5, 1e-9));
    });

    test('reports an unprofitable trade', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 100.0,
      );

      expect(result.profit, closeTo(-4.0, 1e-9));
      expect(result.marginPercent, closeTo(-3.9603960396039604, 1e-9));
      expect(result.isProfitable, isFalse);
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates default break-even sell price', () {
      final result = TradeCalculator.breakEvenSellPrice(buyPrice: 100.0);
      expect(result, closeTo(104.12371134020619, 1e-9));
    });

    test('calculates break-even sell price with custom fees', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 250.0,
        brokerFeePercent: 2.0,
        salesTaxPercent: 4.0,
      );
      expect(result, closeTo(271.27659574468083, 1e-9));
    });
  });

  group('TradeCalculator validation', () {
    test('throws ArgumentError for negative prices', () {
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: -1, sellPrice: 100),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(buyPrice: 100, sellPrice: -1),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for negative fee or tax percentages', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 120,
          brokerFeePercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 120,
          salesTaxPercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          salesTaxPercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when sell-side fees consume the sell price', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 120,
          brokerFeePercent: 70,
          salesTaxPercent: 30,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: 70,
          salesTaxPercent: 30,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
