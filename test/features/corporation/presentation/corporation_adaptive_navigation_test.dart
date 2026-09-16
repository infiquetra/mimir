// C7 RED: four destinations, rail vs bar, destination state preserved.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/presentation/corporation_adaptive_navigation.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: const MaterialApp(home: CorporationAdaptiveNavigation()),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'four destinations use Overview & Roster, Assets, Structures, Wallets',
    (tester) async {
      await pumpAt(tester, const Size(1200, 800));
      expect(find.text('Overview & Roster'), findsWidgets);
      expect(find.text('Assets'), findsWidgets);
      expect(find.text('Structures'), findsWidgets);
      expect(find.text('Wallets'), findsWidgets);
      expect(find.text('Hangars'), findsNothing);
      expect(find.text('Fuel'), findsNothing);
    },
  );

  testWidgets('>= 600 uses NavigationRail', (tester) async {
    await pumpAt(tester, const Size(1200, 800));
    expect(find.byKey(const Key('corporation-module-rail')), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(const Key('corporation-module-bar')), findsNothing);
  });

  testWidgets('< 600 uses NavigationBar', (tester) async {
    await pumpAt(tester, const Size(599, 800));
    expect(find.byKey(const Key('corporation-module-bar')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('corporation-module-rail')), findsNothing);
    expect(
      find.widgetWithText(NavigationDestination, 'Structures'),
      findsOneWidget,
    );
  });

  testWidgets('switching destinations preserves selected tab', (tester) async {
    await pumpAt(tester, const Size(599, 800));
    final target = find.text('Wallets').evaluate().isEmpty
        ? find.text('ISK')
        : find.text('Wallets');
    await tester.tap(target);
    await tester.pump();
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 3);
  });
}
