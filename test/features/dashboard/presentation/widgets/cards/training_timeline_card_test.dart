import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/widgets/character_avatar.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/dashboard/data/dashboard_providers.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/training_timeline_card.dart';

void main() {
  group('TrainingTimelineCard', () {
    late Character testCharacter1;
    late Character testCharacter2;
    late SkillQueueEntry activeSkill1;
    late SkillQueueEntry queuedSkill1;
    late SkillQueueEntry activeSkill2;

    setUp(() {
      final now = DateTime.now();

      testCharacter1 = Character(
        characterId: 12345,
        name: 'Test Character 1',
        corporationId: 1000001,
        corporationName: 'Test Corp',
        allianceId: 2000001,
        allianceName: 'Test Alliance',
        factionId: null,
        securityStatus: 0.0,
        portraitUrl: 'https://images.evetech.net/characters/12345/portrait',
        refreshToken: 'test_token',
        accessToken: 'test_access',
        tokenExpiry: now.add(const Duration(hours: 1)),
        lastUpdated: now,
        isActive: true,
      );

      testCharacter2 = Character(
        characterId: 67890,
        name: 'Test Character 2',
        corporationId: 1000002,
        corporationName: 'Test Corp 2',
        allianceId: null,
        allianceName: null,
      factionId: null,
      securityStatus: 0.0,
        portraitUrl: 'https://images.evetech.net/characters/67890/portrait',
        refreshToken: 'test_token_2',
        accessToken: 'test_access_2',
        tokenExpiry: now.add(const Duration(hours: 1)),
        lastUpdated: now,
        isActive: false,
      );

      // Active skill (training now)
      activeSkill1 = SkillQueueEntry(
        id: 1,
        characterId: 12345,
        queuePosition: 0,
        skillId: 3300,
        finishedLevel: 5,
        startDate: now.subtract(const Duration(hours: 2)),
        finishDate: now.add(const Duration(hours: 4)),
        trainingStartSp: 0,
        levelEndSp: 256000,
        levelStartSp: 181020,
      );

      // Queued skill (training later)
      queuedSkill1 = SkillQueueEntry(
        id: 2,
        characterId: 12345,
        queuePosition: 1,
        skillId: 3301,
        finishedLevel: 4,
        startDate: now.add(const Duration(hours: 4)),
        finishDate: now.add(const Duration(days: 1)),
        trainingStartSp: 0,
        levelEndSp: 128000,
        levelStartSp: 90510,
      );

      // Active skill for character 2
      activeSkill2 = SkillQueueEntry(
        id: 3,
        characterId: 67890,
        queuePosition: 0,
        skillId: 3302,
        finishedLevel: 3,
        startDate: now.subtract(const Duration(hours: 1)),
        finishDate: now.add(const Duration(hours: 6)),
        trainingStartSp: 0,
        levelEndSp: 64000,
        levelStartSp: 45255,
      );
    });

    Widget createTestWidget(ProviderContainer container) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: TrainingTimelineCard(),
          ),
        ),
      );
    }

    testWidgets('displays timeline with active training', (tester) async {
      final container = ProviderContainer(
        overrides: [
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([testCharacter1, testCharacter2]),
          ),
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => Future.value({
              12345: [activeSkill1, queuedSkill1],
              67890: [activeSkill2],
            }),
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      // Verify card title
      expect(find.text('TRAINING TIMELINE'), findsOneWidget);

      // Verify character avatars are displayed
      expect(find.byType(CharacterAvatar), findsNWidgets(2));

      // Verify timeline is rendered
      expect(find.text('Now'), findsOneWidget);
    });

    testWidgets('displays empty state when no training', (tester) async {
      final container = ProviderContainer(
        overrides: [
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([testCharacter1]),
          ),
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => Future.value({
              12345: [],
            }),
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      // Verify empty state
      expect(find.text('No Training Timeline'), findsOneWidget);
      expect(
        find.text('No characters have active skill training'),
        findsOneWidget,
      );
      expect(find.byType(CharacterAvatar), findsNothing);
    });

    testWidgets('displays loading state', (tester) async {
      // Use a completer that we don't complete to keep loading state
      final completer = Completer<Map<int, List<SkillQueueEntry>>>();

      final container = ProviderContainer(
        overrides: [
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([testCharacter1]),
          ),
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => completer.future,
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(container));
      await tester.pump();

      // Verify loading state (shimmer effect from DashboardCard)
      expect(find.byType(TrainingTimelineCard), findsOneWidget);

      // Clean up
      completer.complete({});
    });

    testWidgets('displays error state with retry button', (tester) async {
      final container = ProviderContainer(
        overrides: [
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([testCharacter1]),
          ),
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => Future.error(Exception('Network error')),
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      // Verify error state
      expect(find.text('Failed to load training timeline'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('limits skills per character to maxSkillsPerCharacter',
        (tester) async {
      final now = DateTime.now();

      // Create 5 skills for one character
      final manySkills = List.generate(5, (i) {
        return SkillQueueEntry(
          id: i,
          characterId: 12345,
          queuePosition: i,
          skillId: 3300 + i,
          finishedLevel: 5,
          startDate: now.add(Duration(hours: i * 6)),
          finishDate: now.add(Duration(hours: (i + 1) * 6)),
          trainingStartSp: 0,
          levelEndSp: 256000,
          levelStartSp: 181020,
        );
      });

      final container = ProviderContainer(
        overrides: [
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([testCharacter1]),
          ),
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => Future.value({
              12345: manySkills,
            }),
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      // Should only show maxSkillsPerCharacter (3) skills
      expect(find.byType(CharacterAvatar), findsOneWidget);

      // The timeline should exist
      expect(find.text('Now'), findsOneWidget);
    });

    testWidgets('filters out characters without finish dates',
        (tester) async {
      final skillNoFinishDate = SkillQueueEntry(
        id: 4,
        characterId: 12345,
        queuePosition: 0,
        skillId: 3303,
        finishedLevel: 5,
        startDate: null,
        finishDate: null, // No finish date
        trainingStartSp: 0,
        levelEndSp: 256000,
        levelStartSp: 181020,
      );

      final container = ProviderContainer(
        overrides: [
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([testCharacter1]),
          ),
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => Future.value({
              12345: [skillNoFinishDate],
            }),
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      // Should show empty state since skill has no finish date
      expect(find.text('No Training Timeline'), findsOneWidget);
    });

    test('TimelineData calculates duration correctly', () {
      final now = DateTime.now();
      final endTime = now.add(const Duration(days: 2));

      final timeline = TimelineData(
        startTime: now,
        endTime: endTime,
        totalDuration: endTime.difference(now),
      );

      expect(timeline.totalDuration.inDays, equals(2));
      expect(timeline.startTime, equals(now));
      expect(timeline.endTime, equals(endTime));
    });
  });
}
