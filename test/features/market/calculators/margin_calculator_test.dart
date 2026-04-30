import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator', () {
    group('calculateMargin', () {
      /// Spec formula verification:
      ///   buyTotal  = buyPrice  * (1 + brokerFeePercent / 100)
      ///   sellNet   = sellPrice * (1 - brokerFeePercent / 100 - salesTaxPercent / 100)
      ///   profit    = sellNet - buyTotal
      ///   margin%   = (profit / buyTotal) * 100
      ///   brokerFee = buyPrice * brokerFeePercent / 100 + sellPrice * brokerFeePercent / 100
      ///   salesTax  = sellPrice * salesTaxPercent / 100
      test('calculates margin correctly', () {
        const buyPrice = 1000000.0;
        const sellPrice = 1100000.0;
        const brokerFeePercent = 1.0;
        const salesTaxPercent = 2.0;

        final result = TradeCalculator.calculateMargin(
          buyPrice: buyPrice,
          sellPrice: sellPrice,
          brokerFeePercent: brokerFeePercent,
          salesTaxPercent: salesTaxPercent,
        );

        // buyTotal = 1000000 * (1 + 1/100) = 1010000
        expect(result.buyTotal, equals(1010000.0));
        // sellNet = 1100000 * (1 - 1/100 - 2/100) = 1100000 * 0.97 = 1067000
        expect(result.sellNet, equals(1067000.0));
        // profit = 1067000 - 1010000 = 57000
        expect(result.profit, equals(57000.0));
        // margin% = (57000 / 1010000) * 100 ≈ 5.643564356435644
        expect(result.marginPercent, closeTo(5.643564356435644, 1e-12));
        // brokerFee = 1000000*0.01 + 1100000*0.01 = 10000 + 11000 = 21000
        expect(result.brokerFee, equals(21000.0));
        // salesTax = 1100000 * 0.02 = 22000
        expect(result.salesTax, equals(22000.0));
        // 57000 > 0 → isProfitable
        expect(result.isProfitable, isTrue);
      });

      test(
        'marks unprofitable trades when net sell proceeds are below buy total',
        () {
          const buyPrice = 1000000.0;
          const sellPrice = 1000000.0;

          final result = TradeCalculator.calculateMargin(
            buyPrice: buyPrice,
            sellPrice: sellPrice,
          );

          // buyTotal = 1000000 * 1.01 = 1010000
          // sellNet  = 1000000 * 0.97 = 970000
          // profit   = 970000 - 1010000 = -40000
          expect(result.profit, lessThan(0));
          expect(result.isProfitable, isFalse);
        },
      );

      test(
        'zero buy and sell prices return zero totals without NaN margin',
        () {
          final result = TradeCalculator.calculateMargin(
            buyPrice: 0,
            sellPrice: 0,
          );

          expect(result.buyPrice, equals(0.0));
          expect(result.sellPrice, equals(0.0));
          expect(result.buyTotal, equals(0.0));
          expect(result.sellNet, equals(0.0));
          expect(result.profit, equals(0.0));
          expect(result.marginPercent, equals(0.0));
          expect(result.marginPercent.isNaN, isFalse);
          expect(result.brokerFee, equals(0.0));
          expect(result.salesTax, equals(0.0));
          expect(result.isProfitable, isFalse);
        },
      );

      test('negative prices throw ArgumentError', () {
        expect(
          () => TradeCalculator.calculateMargin(buyPrice: -1, sellPrice: 100),
          throwsArgumentError,
        );
        expect(
          () => TradeCalculator.calculateMargin(buyPrice: 100, sellPrice: -1),
          throwsArgumentError,
        );
      });

      test('non-finite values throw ArgumentError', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: double.nan,
            sellPrice: 100,
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
            brokerFeePercent: double.nan,
          ),
          throwsArgumentError,
        );
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 100,
            salesTaxPercent: double.negativeInfinity,
          ),
          throwsArgumentError,
        );
      });

      test('total fees at or above 100 percent throw ArgumentError', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 100,
            brokerFeePercent: 60,
            salesTaxPercent: 40,
          ),
          throwsArgumentError,
        );
      });
    });

    group('breakEvenSellPrice', () {
      /// Spec formula:
      ///   buyTotal = buyPrice * (1 + brokerFeePercent / 100)
      ///   breakEvenSellPrice = buyTotal / (1 - brokerFeePercent / 100 - salesTaxPercent / 100)
      test('calculates break-even sell price', () {
        const buyPrice = 1000000.0;
        const brokerFeePercent = 1.0;
        const salesTaxPercent = 2.0;

        final result = TradeCalculator.breakEvenSellPrice(
          buyPrice: buyPrice,
          brokerFeePercent: brokerFeePercent,
          salesTaxPercent: salesTaxPercent,
        );

        // buyTotal = 1000000 * 1.01 = 1010000
        // breakEven = 1010000 / (1 - 0.01 - 0.02) = 1010000 / 0.97
        //           ≈ 1041237.1134020619
        expect(result, closeTo(1041237.1134020619, 1e-10));
        // Must cover buy price + fees: > 1010000
        expect(result, greaterThan(1010000.0));
      });

      test('negative buyPrice throws ArgumentError', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(buyPrice: -1),
          throwsArgumentError,
        );
      });

      test('non-finite values throw ArgumentError', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(buyPrice: double.nan),
          throwsArgumentError,
        );
        expect(
          () => TradeCalculator.breakEvenSellPrice(buyPrice: double.infinity),
          throwsArgumentError,
        );
      });

      test('total fees at or above 100 percent throw ArgumentError', () {
        expect(
          () => TradeCalculator.breakEvenSellPrice(
            buyPrice: 100,
            brokerFeePercent: 60,
            salesTaxPercent: 40,
          ),
          throwsArgumentError,
        );
      });
    });
  });
}
