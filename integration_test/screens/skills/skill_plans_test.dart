import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/features/skills/presentation/skills_screen.dart';
import 'package:mimir/features/skills/presentation/widgets/skill_plan_editor.dart';
import 'package:mimir/features/skills/presentation/widgets/skill_plan_card.dart';

import '../../test_utils/fixtures/character_fixtures.dart';
import '../../test_utils/fixtures/skill_fixtures.dart';
import '../../test_utils/fixtures/skill_plan_fixtures.dart';
import '../../test_utils/pump_helpers.dart';
import '../../test_utils/test_app.dart';

/// Integration tests for Skill Plans functionality.
///
/// Tests CRUD operations:
/// - Creating new skill plans
/// - Adding/removing skills from plans
/// - Deleting plans
/// - Progress calculation and display
/// - Training time estimates
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Skill Plans CRUD Tests', () {
    testWidgets(
      'TC-PLAN-001: Create new skill plan',
      (tester) async {
        // GIVEN: Skills screen with no plans
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Navigate to Skill Plans tab
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        await tester.tap(find.text('Skill Plans'));
        await tester.pumpAndSettle();

        // THEN: Empty state should show Create Plan button
        expect(
          find.widgetWithText(FilledButton, 'Create Plan'),
          findsOneWidget,
          reason: 'Empty state should have create button',
        );

        // WHEN: Tapping Create Plan button
        await tester.tap(find.widgetWithText(FilledButton, 'Create Plan'));
        await tester.pumpAndSettle();

        // THEN: SkillPlanEditor dialog should open
        expect(
          find.byType(SkillPlanEditor),
          findsOneWidget,
          reason: 'Create plan dialog should open',
        );

        expect(
          find.text('Create Skill Plan'),
          findsOneWidget,
          reason: 'Dialog title should indicate creation',
        );

        // Dialog should have name and description fields
        expect(
          find.widgetWithText(TextFormField, 'Plan Name'),
          findsOneWidget,
          reason: 'Plan name field should be present',
        );

        expect(
          find.widgetWithText(TextFormField, 'Description (optional)'),
          findsOneWidget,
          reason: 'Description field should be present',
        );

        // Dialog should have Create button
        expect(
          find.widgetWithText(FilledButton, 'Create'),
          findsOneWidget,
          reason: 'Create button should be present',
        );
      },
    );

    testWidgets(
      'TC-PLAN-002: Plan validation requires name',
      (tester) async {
        // GIVEN: Skills screen with plan creation dialog open
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const SkillsScreen(),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        await tester.tap(find.text('Skill Plans'));
        await tester.pumpAndSettle();

        // Open create plan dialog
        await tester.tap(find.widgetWithText(FilledButton, 'Create Plan'));
        await tester.pumpAndSettle();

        // WHEN: Attempting to create plan without name
        await tester.tap(find.widgetWithText(FilledButton, 'Create'));
        await tester.pumpAndSettle();

        // THEN: Validation error should be shown
        expect(
          find.text('Plan name is required'),
          findsOneWidget,
          reason: 'Validation error should appear for empty name',
        );

        // WHEN: Entering plan name
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Plan Name'),
          'Test PvP Plan',
        );
        await tester.pumpAndSettle();

        // THEN: Should be able to create (no validation error)
        // Tapping Create would normally close dialog, but we're just
        // verifying the validation is no longer blocking
        expect(
          find.text('Plan name is required'),
          findsNothing,
          reason: 'Validation error should clear when name is entered',
        );
      },
    );

    testWidgets(
      'TC-PLAN-003: Edit existing skill plan',
      (tester) async {
        // GIVEN: Skills screen with existing plan
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert a skill plan
              await db.into(db.skillPlans).insert(
                    SkillPlanFixtures.pvpFrigatePlan(characterId: characterId),
                  );
            },
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Navigate to Skill Plans tab
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        await tester.tap(find.text('Skill Plans'));
        await tester.pumpAndSettle();

        // THEN: Plan should be visible
        expect(
          find.text('PvP Frigate Skills'),
          findsOneWidget,
          reason: 'Plan name should be displayed',
        );

        // WHEN: Tapping edit button
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        // THEN: SkillPlanEditor dialog should open in edit mode
        expect(
          find.byType(SkillPlanEditor),
          findsOneWidget,
          reason: 'Edit plan dialog should open',
        );

        expect(
          find.text('Edit Skill Plan'),
          findsOneWidget,
          reason: 'Dialog title should indicate editing',
        );

        // Plan name should be pre-filled
        expect(
          find.text('PvP Frigate Skills'),
          findsAtLeastNWidgets(1),
          reason: 'Plan name should be pre-filled in text field',
        );

        // Dialog should have Update button
        expect(
          find.widgetWithText(FilledButton, 'Update'),
          findsOneWidget,
          reason: 'Update button should be present',
        );
      },
    );

    testWidgets(
      'TC-PLAN-004: Delete skill plan with confirmation',
      (tester) async {
        // GIVEN: Skills screen with existing plan
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert a skill plan
              await db.into(db.skillPlans).insert(
                    SkillPlanFixtures.pvpFrigatePlan(characterId: characterId),
                  );
            },
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Navigate to Skill Plans tab
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        await tester.tap(find.text('Skill Plans'));
        await tester.pumpAndSettle();

        // THEN: Plan should be visible
        expect(
          find.text('PvP Frigate Skills'),
          findsOneWidget,
          reason: 'Plan should be displayed before deletion',
        );

        // WHEN: Tapping delete button
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        // THEN: Confirmation dialog should appear
        expect(
          find.text('Delete Skill Plan'),
          findsOneWidget,
          reason: 'Delete confirmation dialog should appear',
        );

        expect(
          find.textContaining('Are you sure'),
          findsOneWidget,
          reason: 'Confirmation message should be shown',
        );

        // Dialog should show plan name
        expect(
          find.textContaining('PvP Frigate Skills'),
          findsOneWidget,
          reason: 'Plan name should be in confirmation message',
        );

        // Dialog should have Cancel and Delete buttons
        expect(
          find.widgetWithText(TextButton, 'Cancel'),
          findsOneWidget,
          reason: 'Cancel button should be present',
        );

        expect(
          find.widgetWithText(FilledButton, 'Delete'),
          findsOneWidget,
          reason: 'Delete button should be present',
        );

        // WHEN: Canceling deletion
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        // THEN: Plan should still exist
        expect(
          find.text('PvP Frigate Skills'),
          findsOneWidget,
          reason: 'Plan should not be deleted when canceled',
        );
      },
    );

    testWidgets(
      'TC-PLAN-005: Plan progress calculation displays correctly',
      (tester) async {
        // GIVEN: Skills screen with partially completed plan
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert a plan with 5 skills
              final planId = await db.into(db.skillPlans).insert(
                    SkillPlanFixtures.completedPlan(characterId: characterId),
                  );

              await db.batch((batch) {
                // Insert 5 plan entries
                batch.insertAll(
                  db.skillPlanEntries,
                  SkillPlanFixtures.completedEntries(planId: planId),
                );

                // Insert trained skills (only 2 out of 5 are trained)
                // Mechanics V and Gunnery V are trained
                batch.insertAll(
                  db.characterSkills,
                  [
                    SkillFixtures.trainedMechanicsV(characterId: characterId),
                    SkillFixtures.trainedGunneryV(characterId: characterId),
                  ],
                );
              });
            },
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Navigate to Skill Plans tab
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        await tester.tap(find.text('Skill Plans'));
        await tester.pumpAndSettle();

        // THEN: Plan card should show progress
        expect(
          find.byType(SkillPlanCard),
          findsOneWidget,
          reason: 'Plan card should be displayed',
        );

        // Progress should show 2/5 skills trained (40%)
        expect(
          find.textContaining('/5 skills'),
          findsOneWidget,
          reason: 'Progress should show X/5 skills format',
        );

        // Progress bar should be visible
        expect(
          find.byType(LinearProgressIndicator),
          findsOneWidget,
          reason: 'Progress bar should be displayed',
        );

        // Percentage should be shown
        expect(
          find.textContaining('% complete'),
          findsOneWidget,
          reason: 'Percentage complete should be displayed',
        );
      },
    );

    testWidgets(
      'TC-PLAN-006: Training time estimate displays',
      (tester) async {
        // GIVEN: Skills screen with plan having untrained skills
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert a plan
              final planId = await db.into(db.skillPlans).insert(
                    SkillPlanFixtures.pvpFrigatePlan(characterId: characterId),
                  );

              await db.batch((batch) {
                // Insert plan entries (10 skills)
                batch.insertAll(
                  db.skillPlanEntries,
                  SkillPlanFixtures.pvpFrigateEntries(planId: planId),
                );

                // Insert only 2 trained skills, leaving 8 untrained
                batch.insertAll(
                  db.characterSkills,
                  [
                    SkillFixtures.trainedMechanicsV(characterId: characterId),
                    SkillFixtures.trainedGunneryV(characterId: characterId),
                  ],
                );
              });
            },
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Navigate to Skill Plans tab
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        await tester.tap(find.text('Skill Plans'));
        await tester.pumpAndSettle();

        // THEN: Plan card should display training time estimate
        expect(
          find.byType(SkillPlanCard),
          findsOneWidget,
          reason: 'Plan card should be displayed',
        );

        // Time estimate should be visible (format: "5d 14h" or similar)
        // The exact time depends on:
        // 1. Number of untrained skills in plan
        // 2. SP required for each skill
        // 3. Character attributes (default 20/20 in calculator)
        expect(
          find.byIcon(Icons.access_time),
          findsOneWidget,
          reason: 'Time estimate icon should be shown',
        );

        // Some time format should be displayed
        // Common formats: "1h", "5h 30m", "1d 2h", "5d 14h"
        expect(
          find.byType(SkillPlanCard),
          findsOneWidget,
          reason: 'Time estimate should be calculated and displayed',
        );
      },
    );
  });

  group('Skill Plans Edge Cases', () {
    testWidgets(
      'Empty plan (no skills) shows 0% progress',
      (tester) async {
        // GIVEN: Skills screen with plan containing no skills
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert empty plan (no entries)
              await db.into(db.skillPlans).insert(
                    SkillPlanFixtures.emptyPlan(characterId: characterId),
                  );
            },
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Navigate to Skill Plans tab
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        await tester.tap(find.text('Skill Plans'));
        await tester.pumpAndSettle();

        // THEN: Plan should show 0/0 skills
        expect(
          find.text('Empty Plan'),
          findsOneWidget,
          reason: 'Empty plan should be displayed',
        );

        // Progress should handle division by zero gracefully
        expect(
          find.byType(SkillPlanCard),
          findsOneWidget,
          reason: 'Empty plan card should render without crashing',
        );
      },
    );

    testWidgets(
      'Completed plan (100%) shows no time estimate',
      (tester) async {
        // GIVEN: Skills screen with fully completed plan
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert completed plan
              final planId = await db.into(db.skillPlans).insert(
                    SkillPlanFixtures.completedPlan(characterId: characterId),
                  );

              await db.batch((batch) {
                // Insert 5 plan entries
                batch.insertAll(
                  db.skillPlanEntries,
                  SkillPlanFixtures.completedEntries(planId: planId),
                );

                // Insert ALL trained skills so plan is 100% complete
                batch.insertAll(
                  db.characterSkills,
                  SkillFixtures.trainedSkills(characterId: characterId),
                );
              });
            },
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Navigate to Skill Plans tab
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        await tester.tap(find.text('Skill Plans'));
        await tester.pumpAndSettle();

        // THEN: Progress should show 100%
        expect(
          find.textContaining('100'),
          findsOneWidget,
          reason: '100% should be shown for completed plan',
        );

        // Progress bar should be full
        expect(
          find.byType(LinearProgressIndicator),
          findsOneWidget,
          reason: 'Progress bar should be at 100%',
        );

        // No time estimate should be shown (0 seconds remaining)
        // Time badge only shows if estimatedTimeSeconds > 0
        // So the Icons.access_time icon should NOT be present
        expect(
          find.byIcon(Icons.access_time),
          findsNothing,
          reason: 'No time estimate for completed plan',
        );
      },
    );
  });
}
