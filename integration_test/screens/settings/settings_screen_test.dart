import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/features/settings/presentation/settings_screen.dart';
import 'package:mimir/features/settings/presentation/widgets/sde_update_card.dart';

import '../../test_utils/pump_helpers.dart';
import '../../test_utils/test_app.dart';

/// Integration tests for the Settings screen.
///
/// Tests the settings screen with:
/// - Startup behavior radio buttons
/// - SDE update card
/// - About card
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Screen Integration Tests', () {
    testWidgets(
      'TC-SET-001: Startup behavior radio buttons work',
      (tester) async {
        // GIVEN: Settings screen
        await tester.pumpWidget(
          const TestApp(
            home: SettingsScreen(),
          ),
        );

        // WHEN: Screen loads
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Both radio button options should be visible
        expect(
          find.text('Open Dashboard'),
          findsOneWidget,
          reason: 'First startup option should be visible',
        );

        expect(
          find.text('Show tray icon only'),
          findsOneWidget,
          reason: 'Second startup option should be visible',
        );

        // AND: Subtitles should be visible
        expect(
          find.text('Show the Dashboard window automatically'),
          findsOneWidget,
          reason: 'Dashboard option subtitle should be visible',
        );

        expect(
          find.text('Launch silently in the menu bar'),
          findsOneWidget,
          reason: 'Tray option subtitle should be visible',
        );

        // AND: Radio buttons should be present
        expect(
          find.byType(RadioListTile<Object>),
          findsNWidgets(2),
          reason: 'Should have 2 radio button options',
        );
      },
    );

    testWidgets(
      'TC-SET-002: SDE update card renders',
      (tester) async {
        // GIVEN: Settings screen
        await tester.pumpWidget(
          const TestApp(
            home: SettingsScreen(),
          ),
        );

        // WHEN: Screen loads
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: SDE update card should be visible
        expect(
          find.byType(SdeUpdateCard),
          findsOneWidget,
          reason: 'SDE update card should render',
        );

        // AND: "Data" section header should be visible
        expect(
          find.text('Data'),
          findsOneWidget,
          reason: 'Data section header should be visible',
        );
      },
    );

    testWidgets(
      'TC-SET-003: About card displays app info',
      (tester) async {
        // GIVEN: Settings screen
        await tester.pumpWidget(
          const TestApp(
            home: SettingsScreen(),
          ),
        );

        // WHEN: Screen loads
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: About section should be visible
        expect(
          find.text('About'),
          findsOneWidget,
          reason: 'About section header should be visible',
        );

        // AND: App name should be visible
        expect(
          find.text('Mimir'),
          findsAtLeastNWidgets(1),
          reason: 'App name should be displayed in About card',
        );

        // AND: About icon should be visible
        expect(
          find.byIcon(Icons.info_outline),
          findsOneWidget,
          reason: 'About icon should be visible',
        );
      },
    );

    testWidgets(
      'TC-SET-004: Settings sections are organized',
      (tester) async {
        // GIVEN: Settings screen
        await tester.pumpWidget(
          const TestApp(
            home: SettingsScreen(),
          ),
        );

        // WHEN: Screen loads
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: All three section headers should be visible
        expect(
          find.text('Startup'),
          findsOneWidget,
          reason: 'Startup section header should be visible',
        );

        expect(
          find.text('Data'),
          findsOneWidget,
          reason: 'Data section header should be visible',
        );

        expect(
          find.text('About'),
          findsOneWidget,
          reason: 'About section header should be visible',
        );

        // AND: Settings should be scrollable
        expect(
          find.byType(ListView),
          findsOneWidget,
          reason: 'Settings should be in a scrollable list',
        );
      },
    );

    testWidgets(
      'TC-SET-005: Settings load without errors',
      (tester) async {
        // GIVEN: Settings screen
        await tester.pumpWidget(
          const TestApp(
            home: SettingsScreen(),
          ),
        );

        // WHEN: Screen loads
        await tester.pumpAndSettle();

        // Wait for settings to load
        await waitForLoadingToComplete(tester);

        // THEN: Settings screen should render successfully
        expect(
          find.byType(SettingsScreen),
          findsOneWidget,
          reason: 'Settings screen should render',
        );

        // AND: Should not show error state
        expect(
          find.text('Failed to load settings'),
          findsNothing,
          reason: 'Should not show error message',
        );
      },
    );
  });
}
