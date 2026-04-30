import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/market/calculators/margin_calculator.dart';

void main() {
  group('TradeCalculator', () {
    test('calculates margin correctly', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1100000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result.buyPrice, equals(1000000));
      expect(result.sellPrice, equals(1100000));
      expect(result.buyTotal, equals(1010000));
      expect(result.sellNet, closeTo(1067000, 0.001));
      expect(result.profit, closeTo(57000, 0.001));
      expect(result.marginPercent, closeTo(5.6435643564, 0.000001));
      expect(result.brokerFee, equals(21000));
      expect(result.salesTax, equals(22000));
      expect(result.isProfitable, isTrue);
    });

    test('calculates break-even sell price', () {
      final result = TradeCalculator.breakEvenSellPrice(
        buyPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result, closeTo(1041237.1134, 0.0001));
      expect(result, greaterThan(1010000));
    });

    test('identifies unprofitable trades', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1000000,
        brokerFeePercent: 1.0,
        salesTaxPercent: 2.0,
      );

      expect(result.profit, lessThan(0));
      expect(result.marginPercent, lessThan(0));
      expect(result.isProfitable, isFalse);
    });

    test('uses default broker fee and sales tax percentages', () {
      final result = TradeCalculator.calculateMargin(
        buyPrice: 1000000,
        sellPrice: 1100000,
      );

      // With default 1% broker fee, 2% sales tax
      expect(result.buyTotal, equals(1010000));
      expect(result.sellNet, closeTo(1067000, 0.001));
      expect(result.profit, closeTo(57000, 0.001));
      expect(result.brokerFee, equals(21000));
      expect(result.salesTax, equals(22000));
    });

    test('rejects non-positive prices', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 0,
          sellPrice: 1000000,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: -100,
          sellPrice: 1000000,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: -100,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: -100),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects NaN prices', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.nan,
          sellPrice: 1000000,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: double.nan,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: double.nan),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects infinite prices', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: double.infinity,
          sellPrice: 1000000,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: double.infinity,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(buyPrice: double.infinity),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects invalid fee percentages', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1000000,
          brokerFeePercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1000000,
          salesTaxPercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          salesTaxPercent: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects NaN fee percentages', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1000000,
          brokerFeePercent: double.nan,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1000000,
          salesTaxPercent: double.nan,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects infinite fee percentages', () {
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1000000,
          brokerFeePercent: double.infinity,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1000000,
          salesTaxPercent: double.infinity,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects combined fees at 100% or more', () {
      // brokerFeePercent + salesTaxPercent >= 100 means sellNet denominator <= 0
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1000000,
          brokerFeePercent: 50,
          salesTaxPercent: 50,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.calculateMargin(
          buyPrice: 1000000,
          sellPrice: 1000000,
          brokerFeePercent: 60,
          salesTaxPercent: 40,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TradeCalculator.breakEvenSellPrice(
          buyPrice: 1000000,
          brokerFeePercent: 50,
          salesTaxPercent: 50,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
