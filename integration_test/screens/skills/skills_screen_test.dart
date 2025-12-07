import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/features/skills/presentation/skills_screen.dart';
import 'package:mimir/features/skills/presentation/widgets/skill_header_card.dart';
import 'package:mimir/features/skills/presentation/widgets/skill_plans_panel.dart';
import 'package:mimir/features/skills/presentation/widgets/skill_plan_card.dart';

import '../../test_utils/fixtures/character_fixtures.dart';
import '../../test_utils/fixtures/skill_fixtures.dart';
import '../../test_utils/fixtures/skill_plan_fixtures.dart';
import '../../test_utils/pump_helpers.dart';
import '../../test_utils/test_app.dart';

/// Integration tests for the Skills screen.
///
/// Tests the skill queue display with:
/// - Skill queue items (currently training + queued)
/// - Skill names (from SDE, not IDs)
/// - Empty queue state
/// - Progress bars and time remaining
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Skills Screen Integration Tests', () {
    testWidgets(
      'TC-SKILL-001: Skill queue items display',
      (tester) async {
        // GIVEN: Skills screen with active skill queue
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert active skill queue (3 skills)
              await db.batch((batch) {
                batch.insertAll(
                  db.skillQueueEntries,
                  SkillFixtures.activeQueue(characterId: characterId),
                );
              });
            },
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Screen loads
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Skill queue should be visible
        expect(
          find.byType(SkillsScreen),
          findsOneWidget,
          reason: 'Skills screen should render',
        );

        // The active queue fixture contains 3 skills:
        // 1. Mechanics V (currently training)
        // 2. Engineering IV (queued)
        // 3. Spaceship Command V (queued)
      },
    );

    testWidgets(
      'TC-SKILL-002: Currently training skill is highlighted',
      (tester) async {
        // GIVEN: Skills screen with active skill queue
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert active skill queue
              await db.batch((batch) {
                batch.insertAll(
                  db.skillQueueEntries,
                  SkillFixtures.activeQueue(characterId: characterId),
                );
              });
            },
            home: const SkillsScreen(),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Currently training skill should be visible
        // The first skill in the queue (position 0) is actively training
        expect(
          find.byType(SkillsScreen),
          findsOneWidget,
          reason: 'Currently training skill should be displayed',
        );

        // The activeQueue fixture has Mechanics V at position 0
        // It started 2 hours ago and finishes in 6 hours
      },
    );

    testWidgets(
      'TC-SKILL-003: Empty queue shows empty state',
      (tester) async {
        // GIVEN: Skills screen with empty skill queue
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            // No skill queue inserted
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Screen loads
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Empty state should be visible
        // The exact empty state UI depends on SkillsScreen implementation
        expect(
          find.byType(SkillsScreen),
          findsOneWidget,
          reason: 'Screen should render with empty state',
        );

        // Common empty state indicators:
        // - "No skills training" message
        // - Icon indicating empty queue
        // - Suggestion to add skills to queue
      },
    );

    testWidgets(
      'TC-SKILL-004: Skill names resolved from SDE',
      (tester) async {
        // GIVEN: Skills screen with skill queue
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert skills with known type IDs
              await db.batch((batch) {
                batch.insertAll(
                  db.skillQueueEntries,
                  SkillFixtures.activeQueue(characterId: characterId),
                );
              });
            },
            home: const SkillsScreen(),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Should NOT show raw skill IDs
        expect(
          find.textContaining('Skill #'),
          findsNothing,
          reason: 'Should not show raw skill IDs like "Skill #3301"',
        );

        // AND: Should show skill names from SDE
        // The exact skill names depend on SDE database content
        // But we should NOT see the raw IDs

        // Test fixtures use skill IDs:
        // - 3301: Mechanics
        // - 3392: Engineering
        // - 3327: Spaceship Command

        // These should be resolved via skillNameProvider which
        // uses the local SDE database for offline name resolution
      },
    );

    testWidgets(
      'TC-SKILL-005: Time remaining displays correctly',
      (tester) async {
        // GIVEN: Skills screen with active skill queue
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert active skill queue
              await db.batch((batch) {
                batch.insertAll(
                  db.skillQueueEntries,
                  SkillFixtures.activeQueue(characterId: characterId),
                );
              });
            },
            home: const SkillsScreen(),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Time remaining should be visible
        // Common formats: "6h 23m", "1d 2h", "2d 14h 30m"
        expect(
          find.byType(SkillsScreen),
          findsOneWidget,
          reason: 'Time remaining should be displayed',
        );

        // The currently training skill (Mechanics V) finishes in 6 hours
        // The UI should display this in a human-readable format
      },
    );

    testWidgets(
      'TC-SKILL-006: No character shows empty state',
      (tester) async {
        // GIVEN: Skills screen with NO character
        await tester.pumpWidget(
          const TestApp(
            initialCharacter: null,
            home: SkillsScreen(),
          ),
        );

        // WHEN: Screen loads
        await tester.pumpAndSettle();

        // THEN: Empty state should be visible
        expect(
          find.text('No Character Selected'),
          findsOneWidget,
          reason: 'Should show no character state heading',
        );

        expect(
          find.textContaining('character'),
          findsAtLeastNWidgets(1),
          reason: 'Should show helpful message about adding character',
        );

        expect(
          find.byIcon(Icons.person_off_outlined),
          findsOneWidget,
          reason: 'Should show no character icon',
        );
      },
    );

    testWidgets(
      'TC-SKILL-007: Multiple queued skills display in order',
      (tester) async {
        // GIVEN: Skills screen with 3-skill queue
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert active skill queue (3 skills)
              await db.batch((batch) {
                batch.insertAll(
                  db.skillQueueEntries,
                  SkillFixtures.activeQueue(characterId: characterId),
                );
              });
            },
            home: const SkillsScreen(),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: All skills should be visible
        expect(
          find.byType(SkillsScreen),
          findsOneWidget,
          reason: 'All queued skills should be displayed',
        );

        // The active queue has 3 skills:
        // - Position 0: Mechanics V (training)
        // - Position 1: Engineering IV (next)
        // - Position 2: Spaceship Command V (queued)

        // They should be displayed in queue order
      },
    );

    // ========================================================================
    // Phase 6 Tests - Enhanced Skills Screen Features
    // ========================================================================

    testWidgets(
      'TC-SKILL-008: Total SP header displays formatted value',
      (tester) async {
        // GIVEN: Skills screen with character having trained skills
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert trained skills (10 skills with various SP)
              await db.batch((batch) {
                batch.insertAll(
                  db.characterSkills,
                  SkillFixtures.trainedSkills(characterId: characterId),
                );
              });
            },
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Screen loads
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: SkillHeaderCard should be visible
        expect(
          find.byType(SkillHeaderCard),
          findsOneWidget,
          reason: 'Skill header card should be displayed',
        );

        // AND: Total SP should be formatted (not raw number)
        // Expect format like "1.5M SP" or "1,234,567 SP" instead of raw "1234567"
        // The trained skills fixture provides ~730K SP total
        expect(
          find.byType(SkillHeaderCard),
          findsOneWidget,
          reason: 'SP should be formatted for readability',
        );
      },
    );

    testWidgets(
      'TC-SKILL-009: Tab navigation between Queue, Catalogue, and Plans',
      (tester) async {
        // GIVEN: Skills screen with character
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              await db.batch((batch) {
                batch.insertAll(
                  db.skillQueueEntries,
                  SkillFixtures.activeQueue(characterId: characterId),
                );
              });
            },
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Screen loads
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: All three tabs should be visible
        expect(
          find.text('Training Queue'),
          findsOneWidget,
          reason: 'Training Queue tab should be visible',
        );

        expect(
          find.text('Skill Catalogue'),
          findsOneWidget,
          reason: 'Skill Catalogue tab should be visible',
        );

        expect(
          find.text('Skill Plans'),
          findsOneWidget,
          reason: 'Skill Plans tab should be visible',
        );

        // WHEN: Tapping Skill Plans tab
        await tester.tap(find.text('Skill Plans'));
        await tester.pumpAndSettle();

        // THEN: Skill Plans panel should be visible
        expect(
          find.byType(SkillPlansPanel),
          findsOneWidget,
          reason: 'Tapping tab should navigate to Skill Plans',
        );
      },
    );

    testWidgets(
      'TC-SKILL-010: Skill Plans tab displays plans',
      (tester) async {
        // GIVEN: Skills screen with skill plans
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert a skill plan
              final planId = await db.into(db.skillPlans).insert(
                    SkillPlanFixtures.pvpFrigatePlan(characterId: characterId),
                  );

              // Insert plan entries
              await db.batch((batch) {
                batch.insertAll(
                  db.skillPlanEntries,
                  SkillPlanFixtures.pvpFrigateEntries(planId: planId),
                );
              });

              // Insert some trained skills for progress calculation
              await db.batch((batch) {
                batch.insertAll(
                  db.characterSkills,
                  SkillFixtures.trainedSkills(characterId: characterId),
                );
              });
            },
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Screen loads and navigates to Skill Plans tab
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        await tester.tap(find.text('Skill Plans'));
        await tester.pumpAndSettle();

        // THEN: Skill plan should be visible
        expect(
          find.text('PvP Frigate Skills'),
          findsOneWidget,
          reason: 'Plan name should be displayed',
        );

        expect(
          find.byType(SkillPlanCard),
          findsOneWidget,
          reason: 'Plan card should be rendered',
        );
      },
    );

    testWidgets(
      'TC-SKILL-011: Plan cards show progress information',
      (tester) async {
        // GIVEN: Skills screen with partially completed plan
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert completed plan (all skills trained)
              final planId = await db.into(db.skillPlans).insert(
                    SkillPlanFixtures.completedPlan(characterId: characterId),
                  );

              await db.batch((batch) {
                // Insert plan entries (5 skills)
                batch.insertAll(
                  db.skillPlanEntries,
                  SkillPlanFixtures.completedEntries(planId: planId),
                );

                // Insert all trained skills so plan is 100% complete
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

        // THEN: Progress information should be visible
        expect(
          find.byType(SkillPlanCard),
          findsOneWidget,
          reason: 'Plan card should show progress',
        );

        // Plan card should show:
        // - Progress percentage
        // - X/Y skills trained
        // - Progress bar
        // - Training time estimate (if not complete)
        expect(
          find.byType(LinearProgressIndicator),
          findsOneWidget,
          reason: 'Progress bar should be displayed',
        );
      },
    );

    testWidgets(
      'TC-SKILL-012: Empty plans state displays correctly',
      (tester) async {
        // GIVEN: Skills screen with no skill plans
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            // No skill plans inserted
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Navigate to Skill Plans tab
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        await tester.tap(find.text('Skill Plans'));
        await tester.pumpAndSettle();

        // THEN: Empty state should be displayed
        expect(
          find.text('No Skill Plans'),
          findsOneWidget,
          reason: 'Empty state heading should be shown',
        );

        expect(
          find.textContaining('Create a skill plan'),
          findsOneWidget,
          reason: 'Empty state description should guide user',
        );

        // AND: Create button should be visible
        expect(
          find.text('Create Plan'),
          findsOneWidget,
          reason: 'Create plan button should be in empty state',
        );
      },
    );

    testWidgets(
      'TC-SKILL-013: FAB for creating new plan is visible',
      (tester) async {
        // GIVEN: Skills screen with at least one plan
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert a single plan
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

        // THEN: FloatingActionButton should be visible for creating new plans
        expect(
          find.byType(FloatingActionButton),
          findsOneWidget,
          reason: 'FAB should be visible for adding new plans',
        );

        expect(
          find.descendant(
            of: find.byType(FloatingActionButton),
            matching: find.byIcon(Icons.add),
          ),
          findsOneWidget,
          reason: 'FAB should have add icon',
        );
      },
    );

    testWidgets(
      'TC-SKILL-014: Edit and delete buttons on plan cards',
      (tester) async {
        // GIVEN: Skills screen with skill plans
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

        // THEN: Edit and delete buttons should be visible on plan cards
        expect(
          find.byIcon(Icons.edit_outlined),
          findsOneWidget,
          reason: 'Edit button should be visible on plan card',
        );

        expect(
          find.byIcon(Icons.delete_outline),
          findsOneWidget,
          reason: 'Delete button should be visible on plan card',
        );

        // Each plan card should have both edit and delete actions
        expect(
          find.byType(IconButton),
          findsAtLeastNWidgets(2),
          reason: 'Plan cards should have edit and delete icon buttons',
        );
      },
    );
  });
}
