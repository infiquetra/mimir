import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/dashboard/data/dashboard_providers.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/training_overview_card.dart';
import 'package:mimir/features/skills/data/skill_providers.dart';
import 'package:mimir/core/sde/sde_providers.dart';

void main() {
  group('TrainingOverviewCard', () {
    late Character testCharacter1;
    late Character testCharacter2;
    late SkillQueueEntry skillEntry1;
    late SkillQueueEntry skillEntry2;

    setUp(() {
      testCharacter1 = Character(
        characterId: 1,
        name: 'Test Pilot 1',
        corporationId: 100,
        corporationName: 'Test Corp',
        portraitUrl: 'https://example.com/portrait1.jpg',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
        isActive: true,
      );

      testCharacter2 = Character(
        characterId: 2,
        name: 'Test Pilot 2',
        corporationId: 100,
        corporationName: 'Test Corp',
        portraitUrl: 'https://example.com/portrait2.jpg',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
        isActive: false,
      );

      skillEntry1 = SkillQueueEntry(
        id: 1,
        characterId: 1,
        queuePosition: 0,
        skillId: 3413,
        finishedLevel: 5,
        startDate: DateTime.now().subtract(const Duration(hours: 1)),
        finishDate: DateTime.now().add(const Duration(hours: 2)),
        trainingStartSp: 1000000,
        levelEndSp: 1500000,
        levelStartSp: 1000000,
      );

      skillEntry2 = SkillQueueEntry(
        id: 2,
        characterId: 2,
        queuePosition: 0,
        skillId: 3300,
        finishedLevel: 4,
        startDate: DateTime.now().subtract(const Duration(hours: 2)),
        finishDate: DateTime.now().add(const Duration(hours: 14)),
        trainingStartSp: 500000,
        levelEndSp: 800000,
        levelStartSp: 500000,
      );
    });

    Widget createTestWidget(List<NextSkillCompletion> completions) {
      return ProviderScope(
        overrides: [
          nextSkillsCompletingProvider.overrideWith(
            (ref) => Future.value(completions),
          ),
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => Future.value({
              1: [skillEntry1],
              2: [skillEntry2],
            }),
          ),
          skillNameProvider(3413).overrideWith(
            (ref) => Future.value('Spaceship Command'),
          ),
          skillNameProvider(3300).overrideWith(
            (ref) => Future.value('Gunnery'),
          ),
          sdeInitializerProvider.overrideWith(
            (ref) => Future.value(null),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TrainingOverviewCard(),
          ),
        ),
      );
    }

    testWidgets('displays card title', (tester) async {
      final completions = [
        NextSkillCompletion(character: testCharacter1, skillEntry: skillEntry1),
      ];

      await tester.pumpWidget(createTestWidget(completions));
      await tester.pump();

      expect(find.text('SKILL TRAINING'), findsOneWidget);
    });

    testWidgets('displays section header', (tester) async {
      final completions = [
        NextSkillCompletion(character: testCharacter1, skillEntry: skillEntry1),
      ];

      await tester.pumpWidget(createTestWidget(completions));
      await tester.pump();

      expect(find.text('COMPLETING SOON'), findsOneWidget);
    });

    testWidgets('handles empty queue', (tester) async {
      await tester.pumpWidget(createTestWidget([]));
      await tester.pump();

      expect(find.text('No Active Training'), findsOneWidget);
      expect(
        find.text('Your characters have no skills in their training queues'),
        findsOneWidget,
      );
    });

    testWidgets('displays character names', (tester) async {
      final completions = [
        NextSkillCompletion(character: testCharacter1, skillEntry: skillEntry1),
        NextSkillCompletion(character: testCharacter2, skillEntry: skillEntry2),
      ];

      await tester.pumpWidget(createTestWidget(completions));
      await tester.pump();

      expect(find.text('Test Pilot 1'), findsOneWidget);
      expect(find.text('Test Pilot 2'), findsOneWidget);
    });

    testWidgets('displays time icon', (tester) async {
      final completions = [
        NextSkillCompletion(character: testCharacter1, skillEntry: skillEntry1),
      ];

      await tester.pumpWidget(createTestWidget(completions));
      await tester.pump();

      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('handles error state', (tester) async {
      final widget = ProviderScope(
        overrides: [
          nextSkillsCompletingProvider.overrideWith(
            (ref) => Future.error('Test error'),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TrainingOverviewCard(),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pump();

      expect(find.text('Failed to load skill training data'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
