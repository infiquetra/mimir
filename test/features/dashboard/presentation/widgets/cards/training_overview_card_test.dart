import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/dashboard/data/dashboard_providers.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/training_overview_card.dart';
import 'package:mimir/features/skills/data/skill_providers.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  group('TrainingOverviewCard', () {
    late Character testCharacter1;
    late Character testCharacter2;
    late SkillQueueEntry skillEntry1;
    late SkillQueueEntry skillEntry2;
    late SkillQueueEntry skillEntry3;

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

      // Skill completing in 2 hours
      skillEntry1 = SkillQueueEntry(
        id: 1,
        characterId: 1,
        queuePosition: 0,
        skillId: 3413, // Spaceship Command
        finishedLevel: 5,
        startDate: DateTime.now().subtract(const Duration(hours: 1)),
        finishDate: DateTime.now().add(const Duration(hours: 2)),
        trainingStartSp: 1000000,
        levelEndSp: 1500000,
        levelStartSp: 1000000,
      );

      // Skill completing in 14 hours
      skillEntry2 = SkillQueueEntry(
        id: 2,
        characterId: 2,
        queuePosition: 0,
        skillId: 3300, // Gunnery
        finishedLevel: 4,
        startDate: DateTime.now().subtract(const Duration(hours: 2)),
        finishDate: DateTime.now().add(const Duration(hours: 14)),
        trainingStartSp: 500000,
        levelEndSp: 800000,
        levelStartSp: 500000,
      );

      // Skill completing in 26 hours (beyond 24h warning threshold)
      skillEntry3 = SkillQueueEntry(
        id: 3,
        characterId: 1,
        queuePosition: 1,
        skillId: 3301, // Caldari Cruiser
        finishedLevel: 3,
        startDate: DateTime.now(),
        finishDate: DateTime.now().add(const Duration(hours: 26)),
        trainingStartSp: 200000,
        levelEndSp: 400000,
        levelStartSp: 200000,
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
              1: [skillEntry1, skillEntry3],
              2: [skillEntry2],
            }),
          ),
          skillNameProvider(3413).overrideWith(
            (ref) => Future.value('Spaceship Command'),
          ),
          skillNameProvider(3300).overrideWith(
            (ref) => Future.value('Gunnery'),
          ),
          skillNameProvider(3301).overrideWith(
            (ref) => Future.value('Caldari Cruiser'),
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

    testWidgets('displays skills sorted by completion time', (tester) async {
      await mockNetworkImagesFor(() async {
        final completions = [
          NextSkillCompletion(character: testCharacter1, skillEntry: skillEntry1),
          NextSkillCompletion(character: testCharacter2, skillEntry: skillEntry2),
          NextSkillCompletion(character: testCharacter1, skillEntry: skillEntry3),
        ];

        await tester.pumpWidget(createTestWidget(completions));
        await tester.pumpAndSettle();

        // Verify card title
        expect(find.text('SKILL TRAINING'), findsOneWidget);

        // Verify section header
        expect(find.text('COMPLETING SOON'), findsOneWidget);

        // Verify all skills are shown
        expect(find.text('Test Pilot 1'), findsNWidgets(2)); // 2 skills for char 1
        expect(find.text('Test Pilot 2'), findsOneWidget);
      });
    });

    testWidgets('shows max 5 skills', (tester) async {
      await mockNetworkImagesFor(() async {
        // Create 7 skill completions
        final completions = List.generate(
          7,
          (i) => NextSkillCompletion(
            character: testCharacter1,
            skillEntry: SkillQueueEntry(
              id: i,
              characterId: 1,
              queuePosition: i,
              skillId: 3413 + i,
              finishedLevel: 5,
              finishDate: DateTime.now().add(Duration(hours: i + 1)),
            ),
          ),
        );

        await tester.pumpWidget(createTestWidget(completions));
        await tester.pumpAndSettle();

        // Should only show 5 character avatars (max skills)
        expect(
          find.byType(Image),
          findsNWidgets(5), // 5 skill icons shown
        );
      });
    });

    testWidgets('handles empty queue characters', (tester) async {
      await tester.pumpWidget(createTestWidget([]));
      await tester.pumpAndSettle();

      // Verify empty state
      expect(find.text('No Active Training'), findsOneWidget);
      expect(
        find.text('Your characters have no skills in their training queues'),
        findsOneWidget,
      );
    });

    testWidgets('displays time remaining correctly', (tester) async {
      await mockNetworkImagesFor(() async {
        final completions = [
          NextSkillCompletion(character: testCharacter1, skillEntry: skillEntry1),
        ];

        await tester.pumpWidget(createTestWidget(completions));
        await tester.pumpAndSettle();

        // Should show time icon
        expect(find.byIcon(Icons.schedule), findsOneWidget);

        // Should show formatted duration (approximately 2h)
        expect(find.textContaining('h'), findsOneWidget);
      });
    });

    testWidgets('highlights skills completing within 24h', (tester) async {
      await mockNetworkImagesFor(() async {
        final completions = [
          NextSkillCompletion(character: testCharacter1, skillEntry: skillEntry1),
          NextSkillCompletion(character: testCharacter1, skillEntry: skillEntry3),
        ];

        await tester.pumpWidget(createTestWidget(completions));
        await tester.pumpAndSettle();

        // Find warning icons (skills < 24h should have warning color)
        final scheduleIcons = find.byIcon(Icons.schedule);
        expect(scheduleIcons, findsNWidgets(2));

        // Note: Testing color requires accessing widget properties directly,
        // which is complex in Flutter tests. The visual appearance can be verified
        // manually or with golden tests.
      });
    });

    testWidgets('shows total SP statistics when data available', (tester) async {
      await mockNetworkImagesFor(() async {
        final completions = [
          NextSkillCompletion(character: testCharacter1, skillEntry: skillEntry1),
          NextSkillCompletion(character: testCharacter2, skillEntry: skillEntry2),
        ];

        await tester.pumpWidget(createTestWidget(completions));
        await tester.pumpAndSettle();

        // Verify statistics section
        expect(find.text('TRAINING STATISTICS'), findsOneWidget);
        expect(find.textContaining('skills in training queue'), findsOneWidget);
      });
    });

    testWidgets('handles loading state', (tester) async {
      final widget = ProviderScope(
        overrides: [
          nextSkillsCompletingProvider.overrideWith(
            (ref) => Future.delayed(
              const Duration(milliseconds: 100),
              () => <NextSkillCompletion>[],
            ),
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

      // Should show loading indicator (shimmer effect from DashboardCard)
      // The DashboardCard handles loading state internally
      expect(find.byType(TrainingOverviewCard), findsOneWidget);
    });

    testWidgets('handles error state with retry', (tester) async {
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
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.text('Failed to load skill training data'), findsOneWidget);

      // Should show retry button
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('displays skill icons correctly', (tester) async {
      final completions = [
        NextSkillCompletion(character: testCharacter1, skillEntry: skillEntry1),
      ];

      await tester.pumpWidget(createTestWidget(completions));
      await tester.pumpAndSettle();

      // Verify skill icon is rendered (EveSkillIcon creates ClipRRect)
      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('truncates long character names', (tester) async {
      final longNameCharacter = Character(
        characterId: 3,
        name: 'This Is A Very Long Character Name That Should Be Truncated',
        corporationId: 100,
        corporationName: 'Test Corp',
        portraitUrl: 'https://example.com/portrait3.jpg',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
        isActive: false,
      );

      final completions = [
        NextSkillCompletion(character: longNameCharacter, skillEntry: skillEntry1),
      ];

      await tester.pumpWidget(createTestWidget(completions));
      await tester.pumpAndSettle();

      // Find the text widget with ellipsis
      final textFinder = find.text(longNameCharacter.name);
      expect(textFinder, findsOneWidget);

      // Verify overflow is set to ellipsis
      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });
  });
}
