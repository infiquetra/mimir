// C9 RED: T49 / U09 F5 balances, journal, trades, Load older, no transfers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/presentation/views/corporation_wallets_view.dart';

void main() {
  Future<void> pumpView(
    WidgetTester tester, {
    Size size = const Size(1200, 800),
    CorporationWalletsView? view,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(home: view ?? const CorporationWalletsView()),
      ),
    );
    await tester.pump();
  }

  testWidgets('complete total is 1500.00 ISK across seven divisions', (
    tester,
  ) async {
    await pumpView(tester);
    expect(find.textContaining('1500.00'), findsWidgets);
    expect(find.textContaining('Division 1'), findsWidgets);
    expect(find.textContaining('Division 7'), findsWidgets);
  });

  testWidgets('missing division 7 is 1200.00 (6/7), not a 0.00 row', (
    tester,
  ) async {
    await pumpView(
      tester,
      view: const CorporationWalletsView(omitDivision7: true),
    );
    expect(find.textContaining('1200.00'), findsWidgets);
    expect(find.textContaining('6/7'), findsWidgets);
    expect(find.text('0.00'), findsNothing);
  });

  testWidgets('journal is +100.40 inflow, -35.40 outflow, +65.00 net', (
    tester,
  ) async {
    await pumpView(tester);
    expect(find.textContaining('100.40'), findsWidgets);
    expect(find.textContaining('35.40'), findsWidgets);
    expect(find.textContaining('65.00'), findsWidgets);
  });

  testWidgets('trades show 3.02 Buy and 20.00 Sell', (tester) async {
    await pumpView(tester);
    expect(find.textContaining('3.02'), findsWidgets);
    expect(find.textContaining('Buy'), findsWidgets);
    expect(find.textContaining('20.00'), findsWidgets);
    expect(find.textContaining('Sell'), findsWidgets);
  });

  testWidgets('Load older is present and management controls are absent', (
    tester,
  ) async {
    await pumpView(tester);
    expect(find.textContaining('Load older'), findsWidgets);
    expect(find.text('Transfer'), findsNothing);
    expect(find.text('Send'), findsNothing);
    expect(find.text('Pay'), findsNothing);
    expect(find.textContaining('Transfer'), findsNothing);
  });

  testWidgets('missing Accountant uses Product §6.6 wallets copy', (
    tester,
  ) async {
    await pumpView(tester, view: const CorporationWalletsView(locked: true));
    expect(find.textContaining('Wallets locked'), findsWidgets);
    expect(
      find.textContaining(
        'Requires Accountant, Junior Accountant or Director and corporation wallet authorization.',
      ),
      findsWidgets,
    );
    expect(find.text('Transfer'), findsNothing);
  });

  testWidgets('320px width does not overflow', (tester) async {
    await pumpView(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });
}
