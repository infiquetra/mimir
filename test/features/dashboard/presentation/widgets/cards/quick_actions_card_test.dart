import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/dashboard/data/dashboard_providers.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/quick_actions_card.dart';

void main() {
  setUp(() {
    // Setup the clipboard testing channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  // Test data
  final testCharacter1 = Character(
    characterId: 1,
    name: 'Test Character 1',
    corporationId: 100,
    corporationName: 'Test Corp',
    allianceId: 200,
    allianceName: 'Test Alliance',
    portraitUrl: 'https://example.com/portrait.jpg',
    tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
    lastUpdated: DateTime.now(),
    isActive: true,
  );

  final testCharacter2 = Character(
    characterId: 2,
    name: 'Test Character 2',
    corporationId: 101,
    corporationName: 'Test Corp 2',
    allianceId: null,
    allianceName: null,
    portraitUrl: 'https://example.com/portrait2.jpg',
    tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
    lastUpdated: DateTime.now(),
    isActive: false,
  );

  final testCharacter3 = Character(
    characterId: 3,
    name: 'Test Character 3',
    corporationId: 102,
    corporationName: 'Test Corp 3',
    allianceId: null,
    allianceName: null,
    portraitUrl: 'https://example.com/portrait3.jpg',
    tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
    lastUpdated: DateTime.now(),
    isActive: false,
  );

  final testSkillEntry1 = SkillQueueEntry(
    id: 1,
    characterId: 1,
    queuePosition: 0,
    skillId: 3300,
    finishedLevel: 3,
    startDate: DateTime.now().subtract(const Duration(hours: 1)),
    finishDate: DateTime.now().add(const Duration(hours: 2)),
    trainingStartSp: 1000,
    levelEndSp: 2000,
    levelStartSp: 500,
  );

  final testSkillEntry2 = SkillQueueEntry(
    id: 2,
    characterId: 2,
    queuePosition: 0,
    skillId: 3301,
    finishedLevel: 4,
    startDate: DateTime.now().subtract(const Duration(hours: 1)),
    finishDate: DateTime.now().add(const Duration(hours: 5)),
    trainingStartSp: 2000,
    levelEndSp: 4000,
    levelStartSp: 1000,
  );

  Widget createTestWidget({
    List<Character>? characters,
    Map<int, List<SkillQueueEntry>>? queues,
    Map<int, double>? balances,
  }) {
    return ProviderScope(
      overrides: [
        if (characters != null)
          allCharactersProvider.overrideWith((ref) => Stream.value(characters)),
        if (queues != null)
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => Future.value(queues),
          ),
        if (balances != null)
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value(balances),
          ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: QuickActionsCard(),
        ),
      ),
    );
  }

  group('QuickActionsCard', () {
    testWidgets('displays loading state correctly',
        (WidgetTester tester) async {
      final widget = ProviderScope(
        overrides: [
          allCharactersProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: QuickActionsCard(),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pump();

      // Should show the card title
      expect(find.text('QUICK ACTIONS'), findsOneWidget);
    });

    testWidgets('displays action buttons correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          characters: [testCharacter1, testCharacter2],
          queues: {
            1: [testSkillEntry1],
            2: [testSkillEntry2],
          },
          balances: {
            1: 1000000.0,
            2: 5000000.0,
          },
        ),
      );
      await tester.pumpAndSettle();

      // Check for action buttons
      expect(find.text('Refresh All'), findsOneWidget);
      expect(find.text('Copy Fleet Status'), findsOneWidget);
    });

    testWidgets('displays empty queue alert correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          characters: [testCharacter1, testCharacter2, testCharacter3],
          queues: {
            1: [testSkillEntry1],
            2: [testSkillEntry2],
            3: [], // Empty queue for character 3
          },
          balances: {
            1: 1000000.0,
            2: 5000000.0,
            3: 500000.0,
          },
        ),
      );
      await tester.pumpAndSettle();

      // Check for ALERTS section
      expect(find.text('ALERTS'), findsOneWidget);

      // Check for alert count badge showing "1"
      expect(find.text('1'), findsOneWidget);

      // Check for empty queue alert
      expect(
          find.text('Test Character 3 has empty skill queue!'), findsOneWidget);

      // Check for warning icon
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('displays multiple alerts correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          characters: [testCharacter1, testCharacter2, testCharacter3],
          queues: {
            1: [], // Empty queue for character 1
            2: [testSkillEntry2],
            3: [], // Empty queue for character 3
          },
          balances: {
            1: 1000000.0,
            2: 5000000.0,
            3: 500000.0,
          },
        ),
      );
      await tester.pumpAndSettle();

      // Check for ALERTS section
      expect(find.text('ALERTS'), findsOneWidget);

      // Check for alert count badge showing "2"
      expect(find.text('2'), findsOneWidget);

      // Check for both empty queue alerts
      expect(
          find.text('Test Character 1 has empty skill queue!'), findsOneWidget);
      expect(
          find.text('Test Character 3 has empty skill queue!'), findsOneWidget);
    });

    testWidgets('no alerts shown when all queues have skills',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          characters: [testCharacter1, testCharacter2],
          queues: {
            1: [testSkillEntry1],
            2: [testSkillEntry2],
          },
          balances: {
            1: 1000000.0,
            2: 5000000.0,
          },
        ),
      );
      await tester.pumpAndSettle();

      // Should not show ALERTS section
      expect(find.text('ALERTS'), findsNothing);
    });

    testWidgets('copy fleet status copies to clipboard',
        (WidgetTester tester) async {
      String? clipboardData;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          clipboardData = (methodCall.arguments as Map)['text'] as String?;
          return null;
        }
        return null;
      });

      await tester.pumpWidget(
        createTestWidget(
          characters: [testCharacter1, testCharacter2],
          queues: {
            1: [testSkillEntry1],
            2: [testSkillEntry2],
          },
          balances: {
            1: 1000000.0,
            2: 5000000.0,
          },
        ),
      );
      await tester.pumpAndSettle();

      // Tap copy fleet status button
      await tester.tap(find.text('Copy Fleet Status'));
      await tester.pumpAndSettle();

      // Verify clipboard data was set
      expect(clipboardData, isNotNull);
      expect(clipboardData, contains('Fleet Status'));
      expect(clipboardData, contains('Test Character 1'));
      expect(clipboardData, contains('Test Character 2'));
      expect(clipboardData, contains('Balance:'));
      expect(clipboardData, contains('Skill Queue:'));

      // Verify success snackbar
      expect(find.text('Fleet status copied to clipboard'), findsOneWidget);
    });

    testWidgets('displays error when data loading fails',
        (WidgetTester tester) async {
      final widget = ProviderScope(
        overrides: [
          allCharactersProvider.overrideWith(
              (ref) => Stream.error(Exception('Failed to load characters'))),
          allCharacterSkillQueuesProvider
              .overrideWith((ref) => Future.value({})),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: QuickActionsCard(),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.textContaining('Failed to load alerts:'), findsOneWidget);
    });

    testWidgets('displays icon and title correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          characters: [testCharacter1],
          queues: {
            1: [testSkillEntry1],
          },
          balances: {
            1: 1000000.0,
          },
        ),
      );
      await tester.pumpAndSettle();

      // Check for bolt icon
      expect(find.byIcon(Icons.bolt), findsOneWidget);

      // Check for card title
      expect(find.text('QUICK ACTIONS'), findsOneWidget);
    });

    testWidgets('formats ISK values correctly in fleet status',
        (WidgetTester tester) async {
      String? clipboardData;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          clipboardData = (methodCall.arguments as Map)['text'] as String?;
          return null;
        }
        return null;
      });

      await tester.pumpWidget(
        createTestWidget(
          characters: [testCharacter1],
          queues: {
            1: [testSkillEntry1],
          },
          balances: {
            1: 1500000000.0, // 1.5B ISK
          },
        ),
      );
      await tester.pumpAndSettle();

      // Tap copy fleet status button
      await tester.tap(find.text('Copy Fleet Status'));
      await tester.pumpAndSettle();

      // Verify clipboard contains formatted ISK (should be in billions)
      expect(clipboardData, contains('1.50B ISK'));
    });

    testWidgets('handles characters with no balance gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          characters: [testCharacter1, testCharacter2],
          queues: {
            1: [testSkillEntry1],
            2: [testSkillEntry2],
          },
          balances: {
            1: 1000000.0,
            // Character 2 has no balance
          },
        ),
      );
      await tester.pumpAndSettle();

      // Should still display the card without errors
      expect(find.text('QUICK ACTIONS'), findsOneWidget);
      expect(find.text('Refresh All'), findsOneWidget);
      expect(find.text('Copy Fleet Status'), findsOneWidget);
    });
  });
}
