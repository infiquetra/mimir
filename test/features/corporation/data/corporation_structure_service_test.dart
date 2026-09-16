// C5 RED: Station Manager structure publication without Director/assets.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/data/corporation_structure_service.dart';
import 'package:mimir/features/corporation/domain/corporation_structure.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  const service = CorporationStructureService();

  test('Dara sees Alpha Works without asset access', () {
    final structures = [
      CorporationStructure(
        id: kAlphaWorksId,
        name: 'Alpha Works',
        fuelExpiresAt: F4Fixtures.expiresAt,
      ),
    ];
    final visible = service.publish(
      roles: F1Fixtures.dara().evidence(),
      structures: structures,
      hasAssetAccess: false,
    );
    expect(visible, hasLength(1));
    expect(visible.single.name, 'Alpha Works');
    expect(service.canView(roles: F1Fixtures.ada().evidence()), isFalse);
  });
}
