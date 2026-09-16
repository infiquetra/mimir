// C9 RED: T50 / U10 AppBar + pull refresh and exact §6.6 snackbar copy.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/presentation/views/corporation_assets_view.dart';
import 'package:mimir/features/corporation/presentation/views/corporation_structures_view.dart';
import 'package:mimir/features/corporation/presentation/views/corporation_wallets_view.dart';
import 'package:mimir/features/corporation/presentation/views/overview_roster_view.dart';

void main() {
  Future<void> pumpView(WidgetTester tester, Widget view) async {
    await tester.pumpWidget(MaterialApp(home: view));
    await tester.pump();
  }

  testWidgets('structures expose AppBar refresh and pull-to-refresh', (
    tester,
  ) async {
    await pumpView(tester, const CorporationStructuresView());
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('wallets expose AppBar refresh and pull-to-refresh', (
    tester,
  ) async {
    await pumpView(tester, const CorporationWalletsView());
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('overview and assets expose AppBar refresh and pull-to-refresh', (
    tester,
  ) async {
    await pumpView(tester, const OverviewRosterView());
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    await pumpView(tester, const CorporationAssetsView());
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('successful refresh uses Corporation data updated.', (
    tester,
  ) async {
    await pumpView(
      tester,
      const CorporationStructuresView(refreshResult: 'success'),
    );
    expect(find.text('Corporation data updated.'), findsOneWidget);
    expect(find.text('Updated.'), findsNothing);
  });

  testWidgets(
    'partial refresh uses Some corporation data could not be updated.',
    (tester) async {
      await pumpView(
        tester,
        const CorporationWalletsView(refreshResult: 'partial'),
      );
      expect(
        find.text('Some corporation data could not be updated.'),
        findsOneWidget,
      );
    },
  );
}
