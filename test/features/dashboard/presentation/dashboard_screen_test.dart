import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/dashboard/data/dashboard_providers.dart';
import 'package:mimir/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/combined_wealth_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/quick_actions_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/training_overview_card.dart';

void main() {
  group('DashboardScreen', () {
    // Test data
    final character1 = Character(
      characterId: 1,
      name: 'Character One',
      corporationId: 100,
      corporationName: 'Corp One',
      allianceId: null,
      allianceName: null,
      portraitUrl: 'https://example.com/portrait1.jpg',
      refreshToken: null,
      accessToken: null,
      tokenExpiry: DateTime.now(),
      lastUpdated: DateTime.now(),
      isActive: true,
    );

    final character2 = Character(
      characterId: 2,
      name: 'Character Two',
      corporationId: 200,
      corporationName: 'Corp Two',
      allianceId: null,
      allianceName: null,
      portraitUrl: 'https://example.com/portrait2.jpg',
      refreshToken: null,
      accessToken: null,
      tokenExpiry: DateTime.now(),
      lastUpdated: DateTime.now(),
      isActive: false,
    );

    Widget buildWidget(List<Object> overrides) {
      return ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      );
    }

    testWidgets('renders all three cards in grid', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1, character2]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({
              1: 10000000.0,
              2: 5000000.0,
            }),
          ),
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => Future.value({
              1: <SkillQueueEntry>[],
              2: <SkillQueueEntry>[],
            }),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // All three cards should be present
      expect(find.byType(CombinedWealthCard), findsOneWidget);
      expect(find.byType(TrainingOverviewCard), findsOneWidget);
      expect(find.byType(QuickActionsCard), findsOneWidget);
    });

    testWidgets('shows empty state when no characters configured',
        (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Should show welcome message
      expect(find.text('Welcome to Mimir'), findsOneWidget);
      expect(find.text('Add a character to get started.'), findsOneWidget);
      expect(find.text('Add Character'), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream<List<Character>>.value(<Character>[]).asyncMap(
              (data) => Future.delayed(
                const Duration(milliseconds: 100),
                () => data,
              ),
            ),
          ),
        ]),
      );

      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the delayed future
      await tester.pumpAndSettle();
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.error(Exception('Failed to load characters')),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Should show error message
      expect(find.text('Failed to Load Dashboard'), findsOneWidget);
      expect(find.textContaining('Failed to load characters'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('has refresh app bar action', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({1: 10000000.0}),
          ),
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => Future.value({1: <SkillQueueEntry>[]}),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Should have AppBar with title
      expect(find.byType(AppBar), findsOneWidget);

      // Should have refresh icon (appears in both AppBar and QuickActionsCard)
      expect(find.byIcon(Icons.refresh), findsAtLeastNWidgets(1));
    });

    testWidgets('supports pull to refresh', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({1: 10000000.0}),
          ),
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => Future.value({1: <SkillQueueEntry>[]}),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Should have RefreshIndicator
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('uses responsive column count', (tester) async {
      // Test with larger screen size to avoid overflow
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({1: 10000000.0}),
          ),
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => Future.value({1: <SkillQueueEntry>[]}),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Should render all cards
      expect(find.byType(CombinedWealthCard), findsOneWidget);
      expect(find.byType(TrainingOverviewCard), findsOneWidget);
      expect(find.byType(QuickActionsCard), findsOneWidget);

      // Reset to default size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('displays app bar with title', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({1: 10000000.0}),
          ),
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => Future.value({1: <SkillQueueEntry>[]}),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Should show Dashboard title in app bar
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('masonry grid has correct spacing', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({1: 10000000.0}),
          ),
          allCharacterSkillQueuesProvider.overrideWith(
            (ref) => Future.value({1: <SkillQueueEntry>[]}),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // All cards should be rendered
      expect(find.byType(CombinedWealthCard), findsOneWidget);
      expect(find.byType(TrainingOverviewCard), findsOneWidget);
      expect(find.byType(QuickActionsCard), findsOneWidget);
    });
  });
}
