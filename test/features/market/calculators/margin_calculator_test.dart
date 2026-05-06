import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator.calculateMargin', () {
    test('calculates profitable default-fee margin', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
      );

      expect(result.buyPrice, 100.0);
      expect(result.sellPrice, 120.0);
      expect(result.buyTotal, 101.0);
      expect(result.sellNet, closeTo(116.4, 0.000001));
      expect(result.profit, closeTo(15.4, 0.000001));
      expect(result.marginPercent, closeTo(15.2475247525, 0.000001));
      expect(result.brokerFee, 2.2);
      expect(result.salesTax, 2.4);
      expect(result.isProfitable, true);
    });

    test('calculates loss-making margin', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 100.0,
      );

      expect(result.buyTotal, 101.0);
      expect(result.sellNet, 97.0);
      expect(result.profit, -4.0);
      expect(result.marginPercent, closeTo(-3.9603960396, 0.000001));
      expect(result.isProfitable, false);
    });

    test('uses custom broker fee and sales tax percentages', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 100.0,
        sellPrice: 120.0,
        brokerFeePercent: 2.0,
        salesTaxPercent: 3.0,
      );

      expect(result.buyTotal, 102.0);
      expect(result.sellNet, 114.0);
      expect(result.profit, 12.0);
      expect(result.brokerFee, 4.4);
      expect(result.salesTax, 3.6);
    });
  });

  group('TradeCalculator.breakEvenSellPrice', () {
    test('calculates break-even sell price with default fees', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100.0,
      );

      // 101.0 / 0.97
      expect(result, closeTo(104.1237113402, 0.000001));
    });

    test('calculates break-even sell price with custom fees', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 100.0,
        brokerFeePercent: 2.0,
        salesTaxPercent: 3.0,
      );

      // 102.0 / 0.95
      expect(result, closeTo(107.3684210526, 0.000001));
    });
  });

  group('TradeCalculator validation', () {
    test('calculateMargin rejects non-positive buy price', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 0.0,
          sellPrice: 120.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: -1.0,
          sellPrice: 120.0,
        ),
        throwsArgumentError,
      );
    });

    test('calculateMargin rejects negative sell price', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 100.0,
          sellPrice: -1.0,
        ),
        throwsArgumentError,
      );
    });

    test('calculateMargin rejects negative fees', () {
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
          salesTaxPercent: -1.0,
        ),
        throwsArgumentError,
      );
    });

    test(
      'calculateMargin rejects total sell fees at or above 100 percent',
      () {
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
            brokerFeePercent: 60.0,
            salesTaxPercent: 50.0,
          ),
          throwsArgumentError,
        );
      },
    );

    test('breakEvenSellPrice rejects invalid inputs', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: 0.0),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: -1.0),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: -1.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          salesTaxPercent: -1.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100.0,
          brokerFeePercent: 50.0,
          salesTaxPercent: 50.0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TradeMargin.isProfitable', () {
    test('returns true when profit is positive', () {
      const margin = TradeMargin(
        buyPrice: 100,
        sellPrice: 120,
        buyTotal: 101,
        sellNet: 116.4,
        profit: 15.4,
        marginPercent: 15.25,
        brokerFee: 2.2,
        salesTax: 2.4,
      );
      expect(margin.isProfitable, true);
    });

    test('returns false when profit is zero', () {
      const margin = TradeMargin(
        buyPrice: 100,
        sellPrice: 100,
        buyTotal: 101,
        sellNet: 97,
        profit: 0,
        marginPercent: 0,
        brokerFee: 2,
        salesTax: 2,
      );
      expect(margin.isProfitable, false);
    });

    test('returns false when profit is negative', () {
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
      expect(margin.isProfitable, false);
    });
  });
}
