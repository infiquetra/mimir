import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/features/skills/data/skill_plan_providers.dart';
import 'package:mimir/features/skills/presentation/widgets/add_to_plan_dialog.dart';

void main() {
  testWidgets('renders skill name and icon', (tester) async {
    final testSkill = SdeType(
      typeId: 3301,
      typeName: 'Mechanics',
      groupId: 255,
    );

    final plans = [
      SkillPlan(
        id: 1,
        characterId: 12345,
        name: 'Test Plan',
        description: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skillPlansProvider.overrideWith((ref) => Stream.value(plans)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddToPlanDialog(
              skill: testSkill,
              trainedLevel: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Verify skill name appears
    expect(find.text('Mechanics'), findsOneWidget);

    // Verify trained level text appears
    expect(find.text('Currently trained: Level 3'), findsOneWidget);
  });

  testWidgets('level selector shows 5 levels', (tester) async {
    final testSkill = SdeType(
      typeId: 3301,
      typeName: 'Mechanics',
      groupId: 255,
    );

    final plans = [
      SkillPlan(
        id: 1,
        characterId: 12345,
        name: 'Test Plan',
        description: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skillPlansProvider.overrideWith((ref) => Stream.value(plans)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddToPlanDialog(
              skill: testSkill,
              trainedLevel: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Should have 5 ChoiceChips for levels 1-5
    expect(find.byType(ChoiceChip), findsNWidgets(5));

    // Level 3 should be selected by default (trainedLevel + 1)
    final level3Chip = tester.widget<ChoiceChip>(
      find.byType(ChoiceChip).at(2), // Index 2 = level 3
    );
    expect(level3Chip.selected, true);
  });

  testWidgets('disables levels <= trained level', (tester) async {
    final testSkill = SdeType(
      typeId: 3301,
      typeName: 'Mechanics',
      groupId: 255,
    );

    final plans = [
      SkillPlan(
        id: 1,
        characterId: 12345,
        name: 'Test Plan',
        description: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skillPlansProvider.overrideWith((ref) => Stream.value(plans)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddToPlanDialog(
              skill: testSkill,
              trainedLevel: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Levels 1, 2, 3 should be disabled (onSelected = null)
    final level1Chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip).at(0));
    final level2Chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip).at(1));
    final level3Chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip).at(2));
    final level4Chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip).at(3));
    final level5Chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip).at(4));

    expect(level1Chip.onSelected, isNull); // Disabled
    expect(level2Chip.onSelected, isNull); // Disabled
    expect(level3Chip.onSelected, isNull); // Disabled
    expect(level4Chip.onSelected, isNotNull); // Enabled
    expect(level5Chip.onSelected, isNotNull); // Enabled
  });

  testWidgets('plan dropdown shows available plans', (tester) async {
    final testSkill = SdeType(
      typeId: 3301,
      typeName: 'Mechanics',
      groupId: 255,
    );

    final plans = [
      SkillPlan(
        id: 1,
        characterId: 12345,
        name: 'PvP Frigate',
        description: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      SkillPlan(
        id: 2,
        characterId: 12345,
        name: 'Mining',
        description: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skillPlansProvider.overrideWith((ref) => Stream.value(plans)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddToPlanDialog(
              skill: testSkill,
              trainedLevel: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Find dropdown button
    expect(find.byType(DropdownButton<int>), findsOneWidget);

    // Tap dropdown to expand
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify both plans appear in dropdown
    expect(find.text('PvP Frigate').hitTestable(), findsOneWidget);
    expect(find.text('Mining').hitTestable(), findsOneWidget);
  });

  testWidgets('shows "no plans" message when no plans exist', (tester) async {
    final testSkill = SdeType(
      typeId: 3301,
      typeName: 'Mechanics',
      groupId: 255,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skillPlansProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddToPlanDialog(
              skill: testSkill,
              trainedLevel: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Verify no plans message
    expect(
      find.text('No skill plans yet. Create one from the Skill Plans tab.'),
      findsOneWidget,
    );

    // Dropdown should not exist
    expect(find.byType(DropdownButton<int>), findsNothing);
  });

  testWidgets('Add button is disabled when no plan selected', (tester) async {
    final testSkill = SdeType(
      typeId: 3301,
      typeName: 'Mechanics',
      groupId: 255,
    );

    final plans = [
      SkillPlan(
        id: 1,
        characterId: 12345,
        name: 'Test Plan',
        description: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skillPlansProvider.overrideWith((ref) => Stream.value(plans)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddToPlanDialog(
              skill: testSkill,
              trainedLevel: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Find Add button
    final addButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Add to Plan'),
    );

    // Should be disabled when no plan selected
    expect(addButton.onPressed, isNull);
  });

  testWidgets('Add button is enabled when plan is selected', (tester) async {
    final testSkill = SdeType(
      typeId: 3301,
      typeName: 'Mechanics',
      groupId: 255,
    );

    final plans = [
      SkillPlan(
        id: 1,
        characterId: 12345,
        name: 'Test Plan',
        description: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skillPlansProvider.overrideWith((ref) => Stream.value(plans)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddToPlanDialog(
              skill: testSkill,
              trainedLevel: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Tap dropdown to expand
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pump(const Duration(milliseconds: 500));

    // Select plan
    await tester.tap(find.text('Test Plan').last);
    await tester.pump(const Duration(milliseconds: 500));

    // Find Add button
    final addButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Add to Plan'),
    );

    // Should now be enabled
    expect(addButton.onPressed, isNotNull);
  });

  testWidgets('Cancel button closes dialog', (tester) async {
    final testSkill = SdeType(
      typeId: 3301,
      typeName: 'Mechanics',
      groupId: 255,
    );

    final plans = [
      SkillPlan(
        id: 1,
        characterId: 12345,
        name: 'Test Plan',
        description: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skillPlansProvider.overrideWith((ref) => Stream.value(plans)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AddToPlanDialog(
                        skill: testSkill,
                        trainedLevel: 3,
                      ),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify dialog is open
    expect(find.byType(AddToPlanDialog), findsOneWidget);

    // Tap Cancel button
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 500));

    // Dialog should be closed
    expect(find.byType(AddToPlanDialog), findsNothing);
  });

  testWidgets('shows loading indicator while fetching plans', (tester) async {
    final testSkill = SdeType(
      typeId: 3301,
      typeName: 'Mechanics',
      groupId: 255,
    );

    // Create a stream that never completes to test loading state
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skillPlansProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddToPlanDialog(
              skill: testSkill,
              trainedLevel: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pump(); // Don't use pumpAndSettle, we want loading state

    // Should show loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error when plan loading fails', skip: true, (tester) async {
    final testSkill = SdeType(
      typeId: 3301,
      typeName: 'Mechanics',
      groupId: 255,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skillPlansProvider.overrideWith(
            (ref) => Stream.error('Database error'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddToPlanDialog(
              skill: testSkill,
              trainedLevel: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Should show error message
    expect(find.textContaining('Failed to load plans'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
