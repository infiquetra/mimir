import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator', () {
    group('calculateMargin', () {
      test('calculates margin correctly', () {
        final result = TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1100000,
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(result.buyPrice, 1000000);
        expect(result.sellPrice, 1100000);
        expect(result.buyTotal, 1010000);
        expect(result.sellNet, closeTo(1067000, 0.001));
        expect(result.profit, closeTo(57000, 0.001));
        expect(result.marginPercent, closeTo(5.6435643564, 0.000001));
        expect(result.brokerFee, 21000);
        expect(result.salesTax, 22000);
        expect(result.isProfitable, isTrue);
      });

      test('uses default fees and reports unprofitable trades', () {
        // Using default brokerFeePercent=1.0 and salesTaxPercent=2.0
        final result = TradeCalculator.calculateMargin(
          buyPrice: 100,
          sellPrice: 100,
        );

        expect(result.buyTotal, 101);
        expect(result.sellNet, 97);
        expect(result.profit, -4);
        expect(result.isProfitable, isFalse);
      });

      test('returns zero margin percent for zero buy total', () {
        final result = TradeCalculator.calculateMargin(
          buyPrice: 0,
          sellPrice: 100,
        );

        expect(result.marginPercent, 0);
        expect(result.profit.isFinite, isTrue);
        expect(result.buyTotal.isFinite, isTrue);
        expect(result.sellNet.isFinite, isTrue);
      });

      test('throws ArgumentError for negative buyPrice', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: -100,
            sellPrice: 100,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for negative sellPrice', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: -100,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for negative brokerFeePercent', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 100,
            brokerFeePercent: -1.0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for negative salesTaxPercent', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 100,
            salesTaxPercent: -1.0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when combined sell-side fees are at least 100 percent', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 100,
            brokerFeePercent: 60,
            salesTaxPercent: 40,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('breakEvenSellPrice', () {
      test('calculates break-even sell price', () {
        final result = TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: 1.0,
          salesTaxPercent: 2.0,
        );

        expect(result, closeTo(1041237.1134, 0.001));
        expect(result, greaterThan(1010000));
      });

      test('break-even returns buy price when fees are zero', () {
        final result = TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: 0,
          salesTaxPercent: 0,
        );

        expect(result, 100);
      });

      test('throws ArgumentError for negative buyPrice', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: -100,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for negative brokerFeePercent', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 100,
            brokerFeePercent: -1.0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for negative salesTaxPercent', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 100,
            salesTaxPercent: -1.0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when combined sell-side fees are at least 100 percent', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 100,
            brokerFeePercent: 60,
            salesTaxPercent: 40,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
