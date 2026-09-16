// C5 RED: Station Manager visibility and elapsed timer captions.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_structure.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  const view = CorporationStructureView();

  test('Station Manager sees structures without Director or assets', () {
    expect(view.visibleWithoutAssets(F1Fixtures.dara().evidence()), isTrue);
    expect(view.visibleWithoutAssets(F1Fixtures.ada().evidence()), isFalse);
  });

  test('elapsed state timer is Awaiting updated state, not Abandoned', () {
    expect(
      view.timerCaption(
        kCorporationT0.subtract(const Duration(hours: 1)),
        kCorporationT0,
      ),
      'Awaiting updated state',
    );
  });
}
