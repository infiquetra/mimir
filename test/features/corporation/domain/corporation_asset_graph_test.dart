// C4 RED: hangar forest, cycles, 65-edge bound, ammo search without crate.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_asset.dart';
import 'package:mimir/features/corporation/domain/corporation_asset_graph.dart';
import 'package:mimir/features/corporation/domain/corporation_decimal.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  final rows = [for (final row in F3Fixtures.rows()) AssetRecord.fromRow(row)];
  const graph = CorporationAssetGraph();

  test('hangar forest nests crate under office and ammo under crate', () {
    final forest = graph.forest(rows);
    expect(forest, hasLength(1));
    final office = forest.single;
    expect(office.record.itemId, 1000);
    final crate = office.children.singleWhere((n) => n.record.itemId == 1100);
    expect(
      crate.children.map((n) => n.record.itemId),
      containsAll([1110, 1120]),
    );
  });

  test('cycle 1400/1401 appears once each in unresolved, no extra value', () {
    final forest = graph.forest(rows);
    final ids = forest
        .expand(
          (n) => [n.record.itemId, ...n.children.map((c) => c.record.itemId)],
        )
        .toList();
    expect(ids.where((id) => id == 1400), hasLength(1));
    expect(ids.where((id) => id == 1401), hasLength(1));
  });

  test('65-edge chain terminates at the depth bound', () {
    final chain = [
      for (var i = 0; i < 66; i++)
        AssetRecord(
          itemId: 2000 + i,
          typeId: 101,
          quantity: 1,
          locationId: i == 0 ? 6001 : 1999 + i,
          locationType: i == 0 ? 'station' : 'item',
        ),
    ];
    expect(graph.exceedsDepthBound(chain), isTrue);
    expect(graph.pathLength(chain), lessThanOrEqualTo(65));
  });

  test('ammo search is 4 matches worth 35.00, crate is ancestor only', () {
    final found = graph.search(
      rows,
      'ammo',
      F3Fixtures.names,
      prices: F3Fixtures.priceMap(),
    );
    expect(found.matchedItemKeys.toSet(), {1110, 1300, 1400, 1401});
    expect(found.matchedItemKeys, hasLength(4));
    expect(found.contextAncestorKeys, contains(1100));
    expect(found.matchedItemKeys, isNot(contains(1100)));
    expect(found.matchedValue, ExactDecimal.parse('35.00'));
  });
}
