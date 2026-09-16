// C4 RED: F3 valuation, BPC exclusion, ExactDecimal fold, unpriced tracking.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_asset.dart';
import 'package:mimir/features/corporation/domain/corporation_decimal.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  final rows = [for (final row in F3Fixtures.rows()) AssetRecord.fromRow(row)];
  const valuation = CorporationAssetValuation();

  AssetValuationResult result() => valuation.value(rows, F3Fixtures.priceMap());

  test('F3 counts: 11 rows, 10 goods, 8 priced, 2 unpriced', () {
    expect(rows, hasLength(11));
    final valued = result();
    expect(valued.goodsCount, 10);
    expect(valued.pricedCount, 8);
    expect(valued.unpricedCount, 2);
  });

  test('F3 division and global oracles', () {
    final valued = result();
    expect(valued.division2.toExactString(), '165.00');
    expect(valued.division1.toExactString(), '550.00');
    expect(valued.unresolvedPriced.toExactString(), '10.00');
    expect(valued.division7Unpriced, 1);
    expect(valued.pricedSubtotal.toExactString(), '725.00');
  });

  test('BPC raw_quantity -2 is unpriced, never 999', () {
    final bpc = rows.singleWhere((row) => row.itemId == 1220);
    expect(bpc.rawQuantity, -2);
    expect(bpc.isBpc, isTrue);
    final valued = result();
    expect(valued.pricedSubtotal.toExactString(), isNot(contains('999')));
    expect(valued.unpricedCount, greaterThanOrEqualTo(1));
  });

  test('ammo 10 × 2.50 is exact 25.00 without double drift', () {
    final ammo = ExactDecimal.parse('2.50') * ExactDecimal.parse('10');
    expect(ammo.toExactString(), '25.00');
    final line = valuation.value([
      const AssetRecord(
        itemId: 1110,
        typeId: 101,
        quantity: 10,
        locationId: 1100,
        locationType: 'item',
        flag: 'Cargo',
      ),
    ], F3Fixtures.priceMap());
    expect(line.pricedSubtotal.toExactString(), '25.00');
  });

  test('unpriced type 9999 is counted, never coerced to 0 ISK', () {
    final valued = valuation.value([
      const AssetRecord(
        itemId: 1500,
        typeId: 9999,
        quantity: 3,
        locationId: 6001,
        locationType: 'station',
        flag: 'CorpSAG7',
      ),
    ], F3Fixtures.priceMap());
    expect(valued.unpricedCount, 1);
    expect(valued.pricedSubtotal.toExactString(), '0.00');
    expect(valued.pricedCount, 0);
  });

  test('negative quantity on 1110 drops 25.00 from priced coverage', () {
    final mutated = [
      for (final row in rows)
        if (row.itemId == 1110)
          AssetRecord(
            itemId: row.itemId,
            typeId: row.typeId,
            quantity: -1,
            locationId: row.locationId,
            locationType: row.locationType,
            flag: row.flag,
            rawQuantity: -1,
            administrative: row.administrative,
          )
        else
          row,
    ];
    final valued = valuation.value(mutated, F3Fixtures.priceMap());
    expect(valued.pricedSubtotal.toExactString(), '700.00');
  });
}
