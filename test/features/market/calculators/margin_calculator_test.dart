import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeMargin', () {
    const margin = TradeMargin(
      buyPrice: 100,
      sellPrice: 200,
      buyTotal: 105,
      sellNet: 190,
      profit: 85,
      marginPercent: 80.95,
      brokerFee: 5,
      salesTax: 4,
    );

    test('isProfitable returns true when profit is positive', () {
      expect(margin.isProfitable, isTrue);
    });

    test('isProfitable returns false when profit is zero', () {
      const zeroProfit = TradeMargin(
        buyPrice: 100,
        sellPrice: 100,
        buyTotal: 100,
        sellNet: 100,
        profit: 0,
        marginPercent: 0,
        brokerFee: 0,
        salesTax: 0,
      );
      expect(zeroProfit.isProfitable, isFalse);
    });

    test('isProfitable returns false when profit is negative', () {
      const loss = TradeMargin(
        buyPrice: 100,
        sellPrice: 80,
        buyTotal: 105,
        sellNet: 75,
        profit: -30,
        marginPercent: -28.57,
        brokerFee: 5,
        salesTax: 2,
      );
      expect(loss.isProfitable, isFalse);
    });

    test('supports value equality', () {
      // Use non-const instances so operator =='s type-check path is exercised.
      // ignore: prefer_const_constructors
      final a = TradeMargin(
        buyPrice: 10,
        sellPrice: 20,
        buyTotal: 12,
        sellNet: 18,
        profit: 6,
        marginPercent: 50,
        brokerFee: 2,
        salesTax: 1,
      );
      const b = TradeMargin(
        buyPrice: 10,
        sellPrice: 20,
        buyTotal: 12,
        sellNet: 18,
        profit: 6,
        marginPercent: 50,
        brokerFee: 2,
        salesTax: 1,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes all fields', () {
      final str = margin.toString();
      expect(str, contains('buyPrice: 100.0'));
      expect(str, contains('sellPrice: 200.0'));
      expect(str, contains('isProfitable: true'));
    });
  });

  group('TradeCalculator', () {
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
      expect(result.sellNet, closeTo(1067000, 0.01));
      expect(result.profit, closeTo(57000, 0.01));
      expect(result.brokerFee, closeTo(21000, 0.01));
      expect(result.salesTax, closeTo(22000, 0.01));
      expect(result.marginPercent, closeTo((57000 / 1010000) * 100, 0.01));
      expect(result.isProfitable, isTrue);
    });

    test('calculates break-even sell price', () {
      const buyPrice = 1000000.0;
      const brokerFeePercent = 1.0;
      const salesTaxPercent = 2.0;

      final breakEven = TradeCalculator.breakEvenSellPrice(
        buyPrice: buyPrice,
        brokerFeePercent: brokerFeePercent,
        salesTaxPercent: salesTaxPercent,
      );

      // Greater than the buy total (the cost basis).
      expect(breakEven, greaterThan(1010000));

      // Should be close to buyTotal / 0.97.
      const buyTotal = buyPrice * (1 + brokerFeePercent / 100);
      expect(breakEven, closeTo(buyTotal / 0.97, 0.01));

      // Round-trip: passing the break-even price into calculateMargin
      // should yield profit ≈ 0.
      final roundTrip = TradeCalculator.calculateMargin(
        buyPrice: buyPrice,
        sellPrice: breakEven,
        brokerFeePercent: brokerFeePercent,
        salesTaxPercent: salesTaxPercent,
      );
      expect(roundTrip.profit, closeTo(0, 0.01));
    });

    test('calculateMargin reports unprofitable trades', () {
      // Sell price below the fee-adjusted buy total produces a loss.
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1010000,
      );

      expect(result.profit, lessThan(0));
      expect(result.marginPercent, lessThan(0));
      expect(result.isProfitable, isFalse);
    });

    test('calculateMargin handles zero buy price without dividing by zero', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 0,
        sellPrice: 200,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result.buyTotal, 0);
      expect(result.marginPercent, 0.0);
      expect(result.isProfitable, isTrue); // free item = pure profit
    });

    test('breakEvenSellPrice returns zero for zero buy price', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 0,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );
      expect(result, 0.0);
    });

    group('throws ArgumentError for invalid prices and fees', () {
      test('negative buyPrice', () {
        expect(
          () => TradeCalculator.calculateMargin(buyPrice: -1, sellPrice: 100),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('negative sellPrice', () {
        expect(
          () => TradeCalculator.calculateMargin(buyPrice: 100, sellPrice: -1),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('NaN buyPrice', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: double.nan,
            sellPrice: 100,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Infinity sellPrice', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: double.infinity,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('combined fees >= 100', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 200,
            brokerFeePercent: 50,
            salesTaxPercent: 50,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('combined fees > 100', () {
        expect(
          () => TradeCalculator.calculateMargin(
            buyPrice: 100,
            sellPrice: 200,
            brokerFeePercent: 60,
            salesTaxPercent: 50,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    test('breakEvenSellPrice validates inputs like calculateMargin', () {
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: -1),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 100,
          brokerFeePercent: 99,
          salesTaxPercent: 1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('calculateMargin with custom fee rates', () {
      // Max skills: 0.75 % broker, 1.5 % sales tax
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1050000,
        brokerFeePercent: 0.75,
        salesTaxPercent: 1.5,
      );

      expect(result.buyTotal, closeTo(1007500, 0.01));
      expect(result.sellNet, closeTo(1026375, 0.01));
      expect(result.profit, closeTo(18875, 0.01));
      expect(result.isProfitable, isTrue);
    });
  });
}
