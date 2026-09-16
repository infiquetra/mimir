// C8 RED: T43 / U03 switch hides old private frame and resets transient filters.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_roster.dart';
import 'package:mimir/features/corporation/presentation/views/corporation_assets_view.dart';
import 'package:mimir/features/corporation/presentation/views/overview_roster_view.dart';

void main() {
  testWidgets('character switch hides old corporation frame immediately', (
    tester,
  ) async {
    final session = CorporationViewSession()
      ..visibleCorporation = 'Helios Research';
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: session,
          builder: (context, _) => OverviewRosterView(session: session),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Helios Research'), findsWidgets);

    session.startSwitch(nextCorporation: 'Selene Works');
    await tester.pump();
    expect(find.textContaining('Helios Research'), findsNothing);
    expect(find.textContaining('Selene Works'), findsNothing);
  });

  test('character switch resets asset search and roster filters', () {
    final session = CorporationViewSession()
      ..assetSearch = 'ammo'
      ..rosterFilter = ActivityBucket.last7;
    session.startSwitch(nextCorporation: 'Selene Works');
    expect(session.assetSearch, isEmpty);
    expect(session.rosterFilter, ActivityBucket.all);
  });

  testWidgets('assets view does not keep the previous search after switch', (
    tester,
  ) async {
    final session = CorporationViewSession()..assetSearch = 'ammo';
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: session,
          builder: (context, _) => CorporationAssetsView(session: session),
        ),
      ),
    );
    await tester.pump();
    session.startSwitch(nextCorporation: 'Selene Works');
    await tester.pump();
    expect(find.textContaining('ammo'), findsNothing);
  });
}
