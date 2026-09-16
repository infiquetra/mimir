// C9 RED: T46 / U06 Station Manager structures, 1440 bay, elapsed timer, lock.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_structure.dart';
import 'package:mimir/features/corporation/presentation/views/corporation_structures_view.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  final alpha = CorporationStructure(
    id: kAlphaWorksId,
    name: 'Alpha Works',
    fuelExpiresAt: F4Fixtures.expiresAt,
    stateTimer: kCorporationT0.subtract(const Duration(hours: 1)),
  );

  Future<void> pumpView(
    WidgetTester tester, {
    Size size = const Size(1200, 800),
    CorporationStructuresView? view,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          home:
              view ??
              CorporationStructuresView(
                roles: F1Fixtures.dara().evidence(),
                hasAssetAccess: false,
                structure: alpha,
                now: kCorporationT0,
                bay: F4Fixtures.bay(),
              ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'Station Manager sees Alpha Works 60h / 2.50 days without Director or assets',
    (tester) async {
      await pumpView(tester);
      expect(find.textContaining('Alpha Works'), findsWidgets);
      expect(find.textContaining('60h'), findsWidgets);
      expect(find.textContaining('2.50'), findsWidgets);
      expect(find.textContaining('8001'), findsNothing);
    },
  );

  testWidgets('observed bay is 1440 StructureFuel blocks', (tester) async {
    await pumpView(tester);
    expect(find.textContaining('1440'), findsWidgets);
    expect(find.textContaining('2240'), findsNothing);
  });

  testWidgets('elapsed timer is Awaiting updated state, not Abandoned', (
    tester,
  ) async {
    await pumpView(tester);
    expect(find.textContaining('Awaiting updated state'), findsWidgets);
    expect(find.textContaining('Abandoned'), findsNothing);
  });

  testWidgets('missing Station Manager uses Product §6.6 structures copy', (
    tester,
  ) async {
    await pumpView(
      tester,
      view: CorporationStructuresView(
        roles: F1Fixtures.ada().evidence(),
        locked: true,
        structure: alpha,
      ),
    );
    expect(find.textContaining('Structures locked'), findsWidgets);
    expect(
      find.textContaining(
        'Requires Station Manager or Director and corporation structure authorization.',
      ),
      findsWidgets,
    );
    expect(find.textContaining('2240'), findsNothing);
  });

  testWidgets('no raw numeric IDs in the structures UI', (tester) async {
    await pumpView(tester);
    expect(find.textContaining('8001'), findsNothing);
    expect(find.textContaining('Structure #'), findsNothing);
  });

  testWidgets('320px width does not overflow', (tester) async {
    await pumpView(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });
}
