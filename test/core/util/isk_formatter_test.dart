import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/util/isk_formatter.dart';

void main() {
  group('formatIsk', () {
    test('formats billions correctly', () {
      expect(formatIsk(1500000000), equals('1.50B ISK'));
      expect(formatIsk(2000000000), equals('2.00B ISK'));
      expect(formatIsk(1000000000), equals('1.00B ISK'));
    });

    test('formats millions correctly', () {
      expect(formatIsk(5000000), equals('5.00M ISK'));
      expect(formatIsk(500000000), equals('500.00M ISK'));
      expect(formatIsk(1000000), equals('1.00M ISK'));
    });

    test('formats thousands correctly', () {
      expect(formatIsk(2500), equals('2.50K ISK'));
      expect(formatIsk(1000), equals('1.00K ISK'));
      expect(formatIsk(999000), equals('999.00K ISK'));
    });

    test('formats raw values correctly', () {
      expect(formatIsk(100), equals('100 ISK'));
      expect(formatIsk(0), equals('0 ISK'));
      expect(formatIsk(999), equals('999 ISK'));
    });

    test('respects decimals parameter', () {
      expect(formatIsk(1500000000, decimals: 0), equals('2B ISK'));
      expect(formatIsk(1500000000, decimals: 1), equals('1.5B ISK'));
      expect(formatIsk(1500000000, decimals: 3), equals('1.500B ISK'));
    });

    test('respects includeSuffix parameter', () {
      expect(formatIsk(1500000000, includeSuffix: false), equals('1.50B'));
      expect(formatIsk(5000000, includeSuffix: false), equals('5.00M'));
      expect(formatIsk(2500, includeSuffix: false), equals('2.50K'));
      expect(formatIsk(100, includeSuffix: false), equals('100'));
    });

    test('throws ArgumentError for negative values', () {
      expect(
        () => formatIsk(-100),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('formatIskCompact', () {
    test('formats without suffix', () {
      expect(formatIskCompact(1500000000), equals('1.50B'));
      expect(formatIskCompact(5000000), equals('5.00M'));
      expect(formatIskCompact(2500), equals('2.50K'));
      expect(formatIskCompact(100), equals('100'));
    });

    test('respects decimals parameter', () {
      expect(formatIskCompact(1500000000, decimals: 1), equals('1.5B'));
      expect(formatIskCompact(5000000, decimals: 0), equals('5M'));
    });
  });
}
