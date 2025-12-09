import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/skills/domain/skill_prerequisite_service.dart';
import 'package:mimir/features/skills/presentation/widgets/prerequisite_warning_dialog.dart';

void main() {
  testWidgets('displays skill being added', (tester) async {
    final unmetPrereqs = [
      const PrerequisiteRequirement(
        skillId: 3318,
        skillName: 'Weapon Upgrades',
        requiredLevel: 5,
        trainedLevel: 3,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrerequisiteWarningDialog(
            skillId: 11441,
            skillName: 'Advanced Weapon Upgrades',
            targetLevel: 1,
            unmetPrerequisites: unmetPrereqs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify skill name appears
    expect(find.text('Advanced Weapon Upgrades'), findsOneWidget);

    // Verify target level appears
    expect(find.text('Target: Level 1'), findsOneWidget);

    // Verify header text
    expect(find.text('Unmet Prerequisites'), findsOneWidget);
  });

  testWidgets('lists all unmet prerequisites', (tester) async {
    final unmetPrereqs = [
      const PrerequisiteRequirement(
        skillId: 3318,
        skillName: 'Weapon Upgrades',
        requiredLevel: 5,
        trainedLevel: 3,
      ),
      const PrerequisiteRequirement(
        skillId: 3327,
        skillName: 'Spaceship Command',
        requiredLevel: 3,
        trainedLevel: 0,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrerequisiteWarningDialog(
            skillId: 11441,
            skillName: 'Advanced Weapon Upgrades',
            targetLevel: 1,
            unmetPrerequisites: unmetPrereqs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify both prerequisites are listed
    expect(find.text('Weapon Upgrades'), findsOneWidget);
    expect(find.text('Spaceship Command'), findsOneWidget);

    // Verify the requirement descriptions
    expect(find.text('Need level 5 (have 3)'), findsOneWidget);
    expect(find.text('Need level 3 (untrained)'), findsOneWidget);
  });

  testWidgets('shows trained vs required levels for partially trained skill', (tester) async {
    final unmetPrereqs = [
      const PrerequisiteRequirement(
        skillId: 3318,
        skillName: 'Weapon Upgrades',
        requiredLevel: 5,
        trainedLevel: 3,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrerequisiteWarningDialog(
            skillId: 11441,
            skillName: 'Advanced Weapon Upgrades',
            targetLevel: 1,
            unmetPrerequisites: unmetPrereqs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify trained level is shown
    expect(find.text('Need level 5 (have 3)'), findsOneWidget);

    // Should show warning icon for partially trained
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

  testWidgets('shows untrained state for completely untrained skill', (tester) async {
    final unmetPrereqs = [
      const PrerequisiteRequirement(
        skillId: 3327,
        skillName: 'Spaceship Command',
        requiredLevel: 3,
        trainedLevel: 0,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrerequisiteWarningDialog(
            skillId: 11441,
            skillName: 'Advanced Weapon Upgrades',
            targetLevel: 1,
            unmetPrerequisites: unmetPrereqs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify untrained status
    expect(find.text('Need level 3 (untrained)'), findsOneWidget);

    // Should show error icon for untrained
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('"Add with Prerequisites" button returns correct result', (tester) async {
    final unmetPrereqs = [
      const PrerequisiteRequirement(
        skillId: 3318,
        skillName: 'Weapon Upgrades',
        requiredLevel: 5,
        trainedLevel: 3,
      ),
    ];

    PrerequisiteDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showDialog<PrerequisiteDialogResult>(
                    context: context,
                    builder: (_) => PrerequisiteWarningDialog(
                      skillId: 11441,
                      skillName: 'Advanced Weapon Upgrades',
                      targetLevel: 1,
                      unmetPrerequisites: unmetPrereqs,
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap "Add with Prerequisites" button
    await tester.tap(find.text('Add with Prerequisites (Recommended)'));
    await tester.pumpAndSettle();

    // Verify result
    expect(result, PrerequisiteDialogResult.addWithPrerequisites);
  });

  testWidgets('"Add Anyway" button returns correct result', (tester) async {
    final unmetPrereqs = [
      const PrerequisiteRequirement(
        skillId: 3318,
        skillName: 'Weapon Upgrades',
        requiredLevel: 5,
        trainedLevel: 3,
      ),
    ];

    PrerequisiteDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showDialog<PrerequisiteDialogResult>(
                    context: context,
                    builder: (_) => PrerequisiteWarningDialog(
                      skillId: 11441,
                      skillName: 'Advanced Weapon Upgrades',
                      targetLevel: 1,
                      unmetPrerequisites: unmetPrereqs,
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap "Add Anyway" button
    await tester.tap(find.text('Add Anyway'));
    await tester.pumpAndSettle();

    // Verify result
    expect(result, PrerequisiteDialogResult.addAnyway);
  });

  testWidgets('Cancel button returns correct result', (tester) async {
    final unmetPrereqs = [
      const PrerequisiteRequirement(
        skillId: 3318,
        skillName: 'Weapon Upgrades',
        requiredLevel: 5,
        trainedLevel: 3,
      ),
    ];

    PrerequisiteDialogResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showDialog<PrerequisiteDialogResult>(
                    context: context,
                    builder: (_) => PrerequisiteWarningDialog(
                      skillId: 11441,
                      skillName: 'Advanced Weapon Upgrades',
                      targetLevel: 1,
                      unmetPrerequisites: unmetPrereqs,
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap Cancel button
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify result
    expect(result, PrerequisiteDialogResult.cancel);
  });

  testWidgets('displays multiple unmet prerequisites in list', (tester) async {
    final unmetPrereqs = [
      const PrerequisiteRequirement(
        skillId: 3318,
        skillName: 'Weapon Upgrades',
        requiredLevel: 5,
        trainedLevel: 3,
      ),
      const PrerequisiteRequirement(
        skillId: 3327,
        skillName: 'Spaceship Command',
        requiredLevel: 3,
        trainedLevel: 0,
      ),
      const PrerequisiteRequirement(
        skillId: 3413,
        skillName: 'Power Grid Management',
        requiredLevel: 4,
        trainedLevel: 2,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrerequisiteWarningDialog(
            skillId: 11441,
            skillName: 'Advanced Weapon Upgrades',
            targetLevel: 1,
            unmetPrerequisites: unmetPrereqs,
          ),
        ),
      ),
    );
    await tester.pump();

    // Find the ListView
    expect(find.byType(ListView), findsOneWidget);

    // Verify all 3 prerequisites are shown
    expect(find.text('Weapon Upgrades'), findsOneWidget);
    expect(find.text('Spaceship Command'), findsOneWidget);
    expect(find.text('Power Grid Management'), findsOneWidget);

    // Verify descriptions
    expect(find.text('Need level 5 (have 3)'), findsOneWidget);
    expect(find.text('Need level 3 (untrained)'), findsOneWidget);
    expect(find.text('Need level 4 (have 2)'), findsOneWidget);
  });

  testWidgets('shows warning message about prerequisites', (tester) async {
    final unmetPrereqs = [
      const PrerequisiteRequirement(
        skillId: 3318,
        skillName: 'Weapon Upgrades',
        requiredLevel: 5,
        trainedLevel: 3,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrerequisiteWarningDialog(
            skillId: 11441,
            skillName: 'Advanced Weapon Upgrades',
            targetLevel: 1,
            unmetPrerequisites: unmetPrereqs,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify warning message
    expect(
      find.text('This skill requires the following prerequisites to be trained first:'),
      findsOneWidget,
    );

    // Verify warning icon
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}
