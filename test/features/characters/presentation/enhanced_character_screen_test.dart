import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/characters/presentation/enhanced_character_screen.dart';

void main() {
  group('EnhancedCharacterScreen', () {
    // Test data
    final testCharacter = Character(
      characterId: 12345,
      name: 'Test Pilot',
      corporationId: 100,
      corporationName: 'Test Corporation',
      allianceId: 200,
      allianceName: 'Test Alliance',
      portraitUrl: 'https://example.com/portrait.jpg',
      refreshToken: null,
      accessToken: null,
      tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
      lastUpdated: DateTime.now(),
      isActive: true,
    );

    Widget buildWidget({Character? character}) {
      return ProviderScope(
        overrides: [
          activeCharacterProvider.overrideWith(
            (ref) => Stream.value(character),
          ),
        ],
        child: const MaterialApp(
          home: EnhancedCharacterScreen(),
        ),
      );
    }

    testWidgets('renders with character selected', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(character: testCharacter));
      await tester.pump();

      // Verify the screen title
      expect(find.text('Character'), findsOneWidget);

      // Verify all three main tabs are present
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Character'), findsOneWidget);
      expect(find.text('Interactions'), findsOneWidget);
    });

    testWidgets('shows three tab icons', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(character: testCharacter));
      await tester.pump();

      // Verify tab icons
      expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outlined), findsOneWidget);
      expect(find.byIcon(Icons.people_outlined), findsOneWidget);
    });

    testWidgets('can switch between tabs', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(character: testCharacter));
      await tester.pump();

      // Tap on Character tab
      await tester.tap(find.text('Character').last);
      await tester.pumpAndSettle();

      // Verify Character tab content is visible (sub-tabs should be present)
      expect(find.text('Attributes'), findsOneWidget);
      expect(find.text('Jump Clones'), findsOneWidget);
      expect(find.text('Skills'), findsOneWidget);

      // Tap on Interactions tab
      await tester.tap(find.text('Interactions').last);
      await tester.pumpAndSettle();

      // Verify Interactions tab content is visible (sub-tabs should be present)
      expect(find.text('Standings'), findsOneWidget);
      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Mail'), findsOneWidget);
    });

    testWidgets('shows refresh button when character is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(character: testCharacter));
      await tester.pump();

      // Verify refresh button is present
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('hides refresh button when no character selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(character: null));
      await tester.pump();

      // Verify refresh button is not present
      expect(find.byIcon(Icons.refresh), findsNothing);
    });
  });

  group('EnhancedCharacterScreen Tab Navigation', () {
    final testCharacter = Character(
      characterId: 12345,
      name: 'Test Pilot',
      corporationId: 100,
      corporationName: 'Test Corporation',
      allianceId: 200,
      allianceName: 'Test Alliance',
      portraitUrl: 'https://example.com/portrait.jpg',
      refreshToken: null,
      accessToken: null,
      tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
      lastUpdated: DateTime.now(),
      isActive: true,
    );

    Widget buildWidget() {
      return ProviderScope(
        overrides: [
          activeCharacterProvider.overrideWith(
            (ref) => Stream.value(testCharacter),
          ),
        ],
        child: const MaterialApp(
          home: EnhancedCharacterScreen(),
        ),
      );
    }

    testWidgets('Character tab shows nested sub-tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      // Switch to Character tab
      await tester.tap(find.text('Character').last);
      await tester.pumpAndSettle();

      // Verify all three sub-tabs are present
      expect(find.text('Attributes'), findsOneWidget);
      expect(find.text('Jump Clones'), findsOneWidget);
      expect(find.text('Skills'), findsOneWidget);
    });

    testWidgets('Interactions tab shows nested sub-tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      // Switch to Interactions tab
      await tester.tap(find.text('Interactions').last);
      await tester.pumpAndSettle();

      // Verify all three sub-tabs are present
      expect(find.text('Standings'), findsOneWidget);
      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Mail'), findsOneWidget);
    });

    testWidgets('can navigate through Character sub-tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      // Switch to Character tab
      await tester.tap(find.text('Character').last);
      await tester.pumpAndSettle();

      // Tap Jump Clones sub-tab
      await tester.tap(find.text('Jump Clones'));
      await tester.pumpAndSettle();

      // Tap Skills sub-tab
      await tester.tap(find.text('Skills'));
      await tester.pumpAndSettle();

      // Tap back to Attributes sub-tab
      await tester.tap(find.text('Attributes'));
      await tester.pumpAndSettle();

      // All sub-tabs should still be visible
      expect(find.text('Attributes'), findsOneWidget);
      expect(find.text('Jump Clones'), findsOneWidget);
      expect(find.text('Skills'), findsOneWidget);
    });
  });
}
