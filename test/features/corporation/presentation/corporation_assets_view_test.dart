// C8 RED: T45 / U05 F3 tree, 725.00 valuation, ammo search, lock/empty copy.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_asset.dart';
import 'package:mimir/features/corporation/presentation/views/corporation_assets_view.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  final rows = [for (final row in F3Fixtures.rows()) AssetRecord.fromRow(row)];

  Future<void> pumpView(
    WidgetTester tester, {
    Size size = const Size(1200, 800),
    CorporationAssetsView? view,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(home: view ?? CorporationAssetsView(rows: rows)),
      ),
    );
    await tester.pump();
  }

  testWidgets('tree shows Alpha Station, office/hangar nest, breadcrumbs', (
    tester,
  ) async {
    await pumpView(tester);
    expect(find.textContaining('Alpha Station'), findsWidgets);
    expect(find.textContaining('Supply Crate'), findsWidgets);
    expect(find.textContaining('6001'), findsNothing);
    expect(find.byKey(const Key('asset-1400')), findsOneWidget);
    expect(find.byKey(const Key('asset-1401')), findsOneWidget);
  });

  testWidgets('valuation is 725.00 ISK with 2 unpriced items, BPC not 999', (
    tester,
  ) async {
    await pumpView(tester);
    expect(find.textContaining('725.00 ISK'), findsWidgets);
    expect(find.textContaining('2 unpriced'), findsWidgets);
    expect(find.textContaining('999'), findsNothing);
    expect(find.textContaining('0.00'), findsNothing);
    expect(find.textContaining('Division 1'), findsWidgets);
    expect(find.textContaining('Division 2'), findsWidgets);
  });

  testWidgets('ammo search is 4 matches worth 35.00; crate is context only', (
    tester,
  ) async {
    await pumpView(
      tester,
      view: CorporationAssetsView(rows: rows, searchQuery: 'ammo'),
    );
    expect(find.textContaining('35.00'), findsWidgets);
    expect(find.textContaining('4 matches'), findsWidgets);
    expect(find.textContaining('Supply Crate'), findsWidgets);
    expect(find.textContaining('Test Ammunition'), findsWidgets);
  });

  testWidgets('Director lock uses Product §6.6 assets copy', (tester) async {
    await pumpView(tester, view: const CorporationAssetsView(locked: true));
    expect(find.textContaining('Assets locked'), findsWidgets);
    expect(
      find.textContaining(
        'Requires Director and corporation asset authorization.',
      ),
      findsWidgets,
    );
    expect(find.textContaining('725'), findsNothing);
  });

  testWidgets('empty cache uses Product §6.6 no-cached-assets copy', (
    tester,
  ) async {
    await pumpView(tester, view: const CorporationAssetsView(empty: true));
    expect(find.textContaining('No cached assets'), findsWidgets);
    expect(
      find.textContaining('Connect and refresh to load this data.'),
      findsWidgets,
    );
  });

  testWidgets('no raw numeric IDs in the assets UI', (tester) async {
    await pumpView(tester);
    expect(find.textContaining('Item #'), findsNothing);
    expect(find.textContaining('6001'), findsNothing);
    expect(find.textContaining('9999'), findsNothing);
  });

  testWidgets('320px width does not overflow', (tester) async {
    await pumpView(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });
}
