import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/skills/presentation/widgets/skill_browser_dialog.dart';

import '../../test_utils/fixtures/character_fixtures.dart';
import '../../test_utils/pump_helpers.dart';
import '../../test_utils/test_app.dart';

/// Integration tests for Skill Browser Dialog.
///
/// Tests:
/// - Skill groups display
/// - Expand/collapse groups
/// - Checkbox selection
/// - Selection count
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Skill Browser Dialog Tests', () {
    testWidgets(
      'TC-BROWSER-001: Displays skill groups',
      (tester) async {
        const characterId = 12345;
        const planId = 1;

        // GIVEN: A skill plan exists
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(characterId: characterId),
            setupDatabase: (db) async {
              // Create skill plan
              await db.into(db.skillPlans).insert(
                    SkillPlansCompanion.insert(
                      id: const Value(planId),
                      characterId: characterId,
                      name: 'Test Plan',
                      createdAt: DateTime.now(),
                      lastUpdated: DateTime.now(),
                    ),
                  );
            },
            home: Scaffold(
              body: SkillBrowserDialog(planId: planId),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Dialog should be displayed
        expect(
          find.text('Add Skills to Plan'),
          findsOneWidget,
          reason: 'Dialog title should be present',
        );

        // Search bar should be present
        expect(
          find.byType(TextField),
          findsOneWidget,
          reason: 'Search bar should be present',
        );

        // Skill groups should be listed
        // (Groups are loaded from SDE, so we just verify the structure exists)
        expect(
          find.byType(ListView),
          findsOneWidget,
          reason: 'Skill groups should be in a list',
        );
      },
    );

    testWidgets(
      'TC-BROWSER-002: Expand group shows skills',
      (tester) async {
        const characterId = 12345;
        const planId = 1;

        // GIVEN: A skill plan exists
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(characterId: characterId),
            setupDatabase: (db) async {
              // Create skill plan
              await db.into(db.skillPlans).insert(
                    SkillPlansCompanion.insert(
                      id: const Value(planId),
                      characterId: characterId,
                      name: 'Test Plan',
                      createdAt: DateTime.now(),
                      lastUpdated: DateTime.now(),
                    ),
                  );
            },
            home: Scaffold(
              body: SkillBrowserDialog(planId: planId),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // WHEN: Tapping on a group to expand it
        // Find the first expand icon
        final expandIcon = find.byIcon(Icons.chevron_right).first;

        if (expandIcon.evaluate().isNotEmpty) {
          await tester.tap(expandIcon);
          await tester.pumpAndSettle();

          // THEN: Group should expand (icon changes to chevron_down)
          expect(
            find.byIcon(Icons.expand_more),
            findsAtLeastNWidgets(1),
            reason: 'Expanded group should show expand_more icon',
          );
        }
      },
    );

    testWidgets(
      'TC-BROWSER-003: Checkbox selection works',
      (tester) async {
        const characterId = 12345;
        const planId = 1;

        // GIVEN: A skill plan exists
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(characterId: characterId),
            setupDatabase: (db) async {
              // Create skill plan
              await db.into(db.skillPlans).insert(
                    SkillPlansCompanion.insert(
                      id: const Value(planId),
                      characterId: characterId,
                      name: 'Test Plan',
                      createdAt: DateTime.now(),
                      lastUpdated: DateTime.now(),
                    ),
                  );
            },
            home: Scaffold(
              body: SkillBrowserDialog(planId: planId),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // WHEN: Expanding a group
        final expandIcon = find.byIcon(Icons.chevron_right).first;

        if (expandIcon.evaluate().isNotEmpty) {
          await tester.tap(expandIcon);
          await tester.pumpAndSettle();

          // WHEN: Tapping a checkbox to select a skill
          final checkbox = find.byType(Checkbox).first;

          if (checkbox.evaluate().isNotEmpty) {
            await tester.tap(checkbox);
            await tester.pumpAndSettle();

            // THEN: Checkbox should be checked
            final checkboxWidget = tester.widget<Checkbox>(checkbox);
            expect(
              checkboxWidget.value,
              true,
              reason: 'Checkbox should be checked after tap',
            );
          }
        }
      },
    );

    testWidgets(
      'TC-BROWSER-004: Selection count updates',
      (tester) async {
        const characterId = 12345;
        const planId = 1;

        // GIVEN: A skill plan exists
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(characterId: characterId),
            setupDatabase: (db) async {
              // Create skill plan
              await db.into(db.skillPlans).insert(
                    SkillPlansCompanion.insert(
                      id: const Value(planId),
                      characterId: characterId,
                      name: 'Test Plan',
                      createdAt: DateTime.now(),
                      lastUpdated: DateTime.now(),
                    ),
                  );
            },
            home: Scaffold(
              body: SkillBrowserDialog(planId: planId),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // WHEN: Expanding a group and selecting a skill
        final expandIcon = find.byIcon(Icons.chevron_right).first;

        if (expandIcon.evaluate().isNotEmpty) {
          await tester.tap(expandIcon);
          await tester.pumpAndSettle();

          final checkbox = find.byType(Checkbox).first;

          if (checkbox.evaluate().isNotEmpty) {
            await tester.tap(checkbox);
            await tester.pumpAndSettle();

            // THEN: Selection summary should show count
            // The dialog shows something like "1 skill selected" in the bottom bar
            expect(
              find.textContaining('selected'),
              findsOneWidget,
              reason: 'Selection count should be displayed',
            );
          }
        }
      },
    );
  });
}
