import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/skills/presentation/skill_plan_detail_screen.dart';

import '../../test_utils/fixtures/character_fixtures.dart';
import '../../test_utils/fixtures/skill_plan_fixtures.dart';
import '../../test_utils/pump_helpers.dart';
import '../../test_utils/test_app.dart';

/// Integration tests for Skill Plan Detail Screen.
///
/// Tests:
/// - Plan header display
/// - Progress bar and stats
/// - Skills list display
/// - Remove skill functionality
/// - Empty state
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Skill Plan Detail Screen Tests', () {
    testWidgets(
      'TC-DETAIL-001: Displays plan header with name',
      (tester) async {
        const characterId = 12345;
        const planId = 1;

        // GIVEN: A skill plan with a name
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(characterId: characterId),
            setupDatabase: (db) async {
              // Create skill plan
              await db.into(db.skillPlans).insert(
                    SkillPlansCompanion.insert(
                      id: const Value(planId),
                      characterId: characterId,
                      name: 'PvP Frigate Plan',
                      description: const Value('Skills for frigate PvP'),
                      createdAt: DateTime.now(),
                      lastUpdated: DateTime.now(),
                    ),
                  );

              // Add some skill entries
              await db.batch((batch) {
                batch.insertAll(db.skillPlanEntries, [
                  SkillPlanEntriesCompanion.insert(
                    planId: planId,
                    skillId: 3301, // Mechanics
                    targetLevel: 5,
                    sortOrder: 0,
                    addedAt: DateTime.now(),
                  ),
                ]);
              });
            },
            home: const SkillPlanDetailScreen(planId: planId),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Plan name should appear in AppBar
        expect(
          find.text('PvP Frigate Plan'),
          findsOneWidget,
          reason: 'Plan name should be displayed in app bar',
        );

        // Edit button should be present
        expect(
          find.byIcon(Icons.edit_outlined),
          findsOneWidget,
          reason: 'Edit button should be present',
        );
      },
    );

    testWidgets(
      'TC-DETAIL-002: Shows progress bar and stats',
      (tester) async {
        const characterId = 12345;
        const planId = 1;

        // GIVEN: A skill plan with 3 skills (1 trained, 2 untrained)
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

              // Add 3 skills to plan
              await db.batch((batch) {
                batch.insertAll(db.skillPlanEntries, [
                  SkillPlanEntriesCompanion.insert(
                    planId: planId,
                    skillId: 3301, // Mechanics
                    targetLevel: 5,
                    sortOrder: 0,
                    addedAt: DateTime.now(),
                  ),
                  SkillPlanEntriesCompanion.insert(
                    planId: planId,
                    skillId: 3302, // Engineering
                    targetLevel: 4,
                    sortOrder: 1,
                    addedAt: DateTime.now(),
                  ),
                  SkillPlanEntriesCompanion.insert(
                    planId: planId,
                    skillId: 3303, // Shield Management
                    targetLevel: 3,
                    sortOrder: 2,
                    addedAt: DateTime.now(),
                  ),
                ]);
              });

              // Mechanics is trained to level 5 (complete!)
              await db.batch((batch) {
                batch.insertAll(db.characterSkills, [
                  CharacterSkillsCompanion.insert(
                    characterId: characterId,
                    skillId: 3301,
                    trainedSkillLevel: 5,
                    activeSkillLevel: 5,
                    skillpointsInSkill: 256000,
                    lastUpdated: DateTime.now(),
                  ),
                ]);
              });
            },
            home: const SkillPlanDetailScreen(planId: planId),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Progress should show 1/3 skills (33.3%)
        expect(
          find.textContaining('Progress: 1/3 skills'),
          findsOneWidget,
          reason: 'Progress text should show trained/total',
        );

        expect(
          find.textContaining('33.3%'),
          findsOneWidget,
          reason: 'Percentage should be displayed',
        );

        // Progress bar should be present
        expect(
          find.byType(LinearProgressIndicator),
          findsOneWidget,
          reason: 'Progress bar should be displayed',
        );

        // Est. Time should be present (may be "—" if not calculated yet)
        expect(
          find.textContaining('Est. Time:'),
          findsOneWidget,
          reason: 'Estimated time label should be present',
        );
      },
    );

    testWidgets(
      'TC-DETAIL-003: Lists skills in plan',
      (tester) async {
        const characterId = 12345;
        const planId = 1;

        // GIVEN: A skill plan with multiple skills
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

              // Add skills to plan
              await db.batch((batch) {
                batch.insertAll(db.skillPlanEntries, [
                  SkillPlanEntriesCompanion.insert(
                    planId: planId,
                    skillId: 3301, // Mechanics
                    targetLevel: 5,
                    sortOrder: 0,
                    addedAt: DateTime.now(),
                  ),
                  SkillPlanEntriesCompanion.insert(
                    planId: planId,
                    skillId: 3302, // Engineering
                    targetLevel: 4,
                    sortOrder: 1,
                    addedAt: DateTime.now(),
                  ),
                ]);
              });
            },
            home: const SkillPlanDetailScreen(planId: planId),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Skills should be listed
        // Note: Skill names will be resolved via skillNameProvider
        expect(
          find.byType(ReorderableListView),
          findsOneWidget,
          reason: 'Skills should be in a reorderable list',
        );

        // Should have entries for both skills
        // (checking for skill IDs or icons since names are async)
        expect(
          find.byType(ListTile),
          findsAtLeast(2),
          reason: 'Should have list tiles for each skill',
        );
      },
    );

    testWidgets(
      'TC-DETAIL-004: Remove skill from plan',
      (tester) async {
        const characterId = 12345;
        const planId = 1;

        // GIVEN: A skill plan with one skill
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

              // Add one skill
              await db.into(db.skillPlanEntries).insert(
                    SkillPlanEntriesCompanion.insert(
                      planId: planId,
                      skillId: 3301, // Mechanics
                      targetLevel: 5,
                      sortOrder: 0,
                      addedAt: DateTime.now(),
                    ),
                  );
            },
            home: const SkillPlanDetailScreen(planId: planId),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // WHEN: Tapping remove button (icon button with delete icon)
        final removeButton = find.byIcon(Icons.delete_outline);
        expect(
          removeButton,
          findsOneWidget,
          reason: 'Remove button should be present',
        );

        await tester.tap(removeButton);
        await tester.pumpAndSettle();

        // THEN: Empty state should appear
        expect(
          find.byIcon(Icons.list_alt_outlined),
          findsOneWidget,
          reason: 'Empty state icon should appear after removing skill',
        );

        expect(
          find.textContaining('No skills in this plan yet'),
          findsOneWidget,
          reason: 'Empty state message should appear',
        );
      },
    );

    testWidgets(
      'TC-DETAIL-005: Empty plan shows add skills prompt',
      (tester) async {
        const characterId = 12345;
        const planId = 1;

        // GIVEN: An empty skill plan
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(characterId: characterId),
            setupDatabase: (db) async {
              // Create skill plan with no entries
              await db.into(db.skillPlans).insert(
                    SkillPlansCompanion.insert(
                      id: const Value(planId),
                      characterId: characterId,
                      name: 'Empty Plan',
                      createdAt: DateTime.now(),
                      lastUpdated: DateTime.now(),
                    ),
                  );
            },
            home: const SkillPlanDetailScreen(planId: planId),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Empty state should be displayed
        expect(
          find.byIcon(Icons.list_alt_outlined),
          findsOneWidget,
          reason: 'Empty state icon should be present',
        );

        expect(
          find.textContaining('No skills in this plan yet'),
          findsOneWidget,
          reason: 'Empty state message should be displayed',
        );

        expect(
          find.textContaining('Add skills to get started'),
          findsOneWidget,
          reason: 'Empty state description should be displayed',
        );

        // Add Skills FAB should be present
        expect(
          find.widgetWithText(FloatingActionButton, 'Add Skills'),
          findsOneWidget,
          reason: 'Add Skills button should be present',
        );
      },
    );
  });
}
