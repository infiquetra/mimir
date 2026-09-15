// X7 RED contracts for ExplorationScreen responsive navigation.
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §6.3:
// - module NavigationRail only when usable module width >= 600
// - NavigationBar below 600 with Database/Connections/Signatures/Routes
// - CharacterNavRail yields to a compact AppBar menu below 600
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/presentation/exploration_screen.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: const MaterialApp(home: ExplorationScreen()),
      ),
    );
    await tester.pump();
  }

  group('ExplorationScreen shell', () {
    testWidgets('>= 600 module width uses NavigationRail', (tester) async {
      await pumpAt(tester, const Size(1440, 900));
      expect(find.byKey(const Key('exploration-module-rail')), findsOneWidget);
      expect(find.byKey(const Key('exploration-module-bar')), findsNothing);
      expect(
        find.byKey(const Key('exploration-character-rail')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('exploration-character-menu')), findsNothing);
      expect(find.text('Database'), findsWidgets);
      expect(find.text('Connections'), findsWidgets);
      expect(find.text('Signatures'), findsWidgets);
      expect(find.text('Routes'), findsWidgets);
    });

    testWidgets(
      '< 600 module width uses NavigationBar and compact character menu',
      (tester) async {
        await pumpAt(tester, const Size(599, 800));
        expect(find.byKey(const Key('exploration-module-bar')), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byKey(const Key('exploration-module-rail')), findsNothing);
        expect(
          find.byKey(const Key('exploration-character-rail')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('exploration-character-menu')),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(NavigationDestination, 'Database'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(NavigationDestination, 'Connections'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(NavigationDestination, 'Signatures'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(NavigationDestination, 'Routes'),
          findsOneWidget,
        );
      },
    );
  });
}
