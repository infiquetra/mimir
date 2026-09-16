// C4 RED: mixed-generation pages, 1001-ID name batches, private name isolation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/data/corporation_asset_service.dart';
import 'package:mimir/features/corporation/domain/corporation_asset.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  const service = CorporationAssetService();
  final rows = [for (final row in F3Fixtures.rows()) AssetRecord.fromRow(row)];

  test('mixed snapshot generations do not publish complete inventory', () {
    expect(
      service.acceptsMixedGeneration(const [
        AssetNamePage(ids: [1000], generation: 1),
        AssetNamePage(ids: [1100], generation: 2),
      ]),
      isFalse,
    );
    final published = service.publish(const [
      AssetNamePage(ids: [1000], generation: 1),
      AssetNamePage(ids: [1100], generation: 2),
    ], rows);
    expect(published.complete, isFalse);
  });

  test('1001 item IDs split into batches of at most 1000', () {
    final ids = [for (var i = 0; i < 1001; i++) 10000 + i];
    final batches = service.nameBatches(ids);
    expect(batches, hasLength(2));
    expect(batches.first, hasLength(1000));
    expect(batches.last, hasLength(1));
    expect(batches.every((batch) => batch.length <= 1000), isTrue);
  });

  test('Ada does not see Cyra custom names or Item # fallbacks', () {
    final name = service.displayName(
      itemId: 1100,
      viewerCharacterId: kAdaId,
      typeId: 100,
      typeNames: F3Fixtures.names,
      customNamesByCharacter: {
        kCyraId: {1100: 'Supply Crate'},
      },
    );
    expect(name, 'Small Container');
    expect(name, isNot('Supply Crate'));
    expect(name, isNot(contains('1100')));
    expect(name, isNot(contains('Item #')));
  });
}
