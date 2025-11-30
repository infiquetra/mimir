import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mimir/features/dashboard/data/combat_providers.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/combat_stats_card.dart';

void main() {
  group('CombatStatsCard', () {
    testWidgets('should render card title correctly', (WidgetTester tester) async {
      // Arrange - provide dummy data
      const stats = AggregateCombatStats(
        totalKills: 100,
        totalDeaths: 50,
        totalIskDestroyed: 10000000000.0,
        totalIskLost: 5000000000.0,
        characterStats: [],
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCharacterCombatStatsProvider.overrideWith(
              (ref) => Future.value(stats),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: CombatStatsCard(),
            ),
          ),
        ),
      );

      // Allow for async providers to resolve
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('COMBAT STATS'), findsOneWidget);
      expect(find.byIcon(Icons.military_tech_outlined), findsOneWidget);
    });

    testWidgets('should display aggregate stats when data available',
        (WidgetTester tester) async {
      // Arrange
      const char1 = CombatStatsData(
        characterId: 1,
        characterName: 'Test Character 1',
        kills: 100,
        deaths: 50,
        iskDestroyed: 10000000000.0,
        iskLost: 5000000000.0,
      );

      const char2 = CombatStatsData(
        characterId: 2,
        characterName: 'Test Character 2',
        kills: 50,
        deaths: 25,
        iskDestroyed: 5000000000.0,
        iskLost: 2500000000.0,
      );

      const stats = AggregateCombatStats(
        totalKills: 150,
        totalDeaths: 75,
        totalIskDestroyed: 15000000000.0,
        totalIskLost: 7500000000.0,
        characterStats: [char1, char2],
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCharacterCombatStatsProvider.overrideWith(
              (ref) => Future.value(stats),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: CombatStatsCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('COMBAT STATS'), findsOneWidget);
      expect(find.text('ALL CHARACTERS'), findsOneWidget);
      expect(find.text('150'), findsOneWidget); // Total kills
      expect(find.text('75'), findsOneWidget); // Total deaths
      expect(find.text('2.00'), findsOneWidget); // K/D ratio
      expect(find.text('BY CHARACTER'), findsOneWidget);
      expect(find.text('Test Character 1'), findsOneWidget);
      expect(find.text('Test Character 2'), findsOneWidget);
    });

    testWidgets('should show empty state when no activity',
        (WidgetTester tester) async {
      // Arrange
      const stats = AggregateCombatStats(
        totalKills: 0,
        totalDeaths: 0,
        totalIskDestroyed: 0.0,
        totalIskLost: 0.0,
        characterStats: [],
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCharacterCombatStatsProvider.overrideWith(
              (ref) => Future.value(stats),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: CombatStatsCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('COMBAT STATS'), findsOneWidget);
      expect(find.text('No Combat Data'), findsOneWidget);
      expect(
        find.text('Your characters have no recorded combat activity'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('should display kills stat box correctly',
        (WidgetTester tester) async {
      // Arrange
      const stats = AggregateCombatStats(
        totalKills: 100,
        totalDeaths: 50,
        totalIskDestroyed: 10000000000.0,
        totalIskLost: 5000000000.0,
        characterStats: [],
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCharacterCombatStatsProvider.overrideWith(
              (ref) => Future.value(stats),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: CombatStatsCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('KILLS'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('should display deaths stat box correctly',
        (WidgetTester tester) async {
      // Arrange
      const stats = AggregateCombatStats(
        totalKills: 100,
        totalDeaths: 50,
        totalIskDestroyed: 10000000000.0,
        totalIskLost: 5000000000.0,
        characterStats: [],
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCharacterCombatStatsProvider.overrideWith(
              (ref) => Future.value(stats),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: CombatStatsCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('DEATHS'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    });

    testWidgets('should display K/D ratio stat box correctly',
        (WidgetTester tester) async {
      // Arrange
      const stats = AggregateCombatStats(
        totalKills: 100,
        totalDeaths: 50,
        totalIskDestroyed: 10000000000.0,
        totalIskLost: 5000000000.0,
        characterStats: [],
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCharacterCombatStatsProvider.overrideWith(
              (ref) => Future.value(stats),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: CombatStatsCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('K/D RATIO'), findsOneWidget);
      expect(find.text('2.00'), findsOneWidget);
      expect(find.byIcon(Icons.assessment_outlined), findsOneWidget);
    });

    testWidgets('should display ISK stat boxes correctly',
        (WidgetTester tester) async {
      // Arrange
      const stats = AggregateCombatStats(
        totalKills: 100,
        totalDeaths: 50,
        totalIskDestroyed: 10000000000.0,
        totalIskLost: 5000000000.0,
        characterStats: [],
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCharacterCombatStatsProvider.overrideWith(
              (ref) => Future.value(stats),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: CombatStatsCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('ISK DESTROYED'), findsOneWidget);
      expect(find.text('ISK LOST'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
      expect(find.byIcon(Icons.trending_down), findsOneWidget);
    });

    testWidgets('should display character rows correctly',
        (WidgetTester tester) async {
      // Arrange
      const char1 = CombatStatsData(
        characterId: 1,
        characterName: 'Test Character',
        kills: 100,
        deaths: 50,
        iskDestroyed: 10000000000.0,
        iskLost: 5000000000.0,
      );

      const stats = AggregateCombatStats(
        totalKills: 100,
        totalDeaths: 50,
        totalIskDestroyed: 10000000000.0,
        totalIskLost: 5000000000.0,
        characterStats: [char1],
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCharacterCombatStatsProvider.overrideWith(
              (ref) => Future.value(stats),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: CombatStatsCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Test Character'), findsOneWidget);
      expect(find.text('100 kills / 50 deaths'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget); // Positive danger rating
      // Note: We expect two "50" texts - one from deaths stat box, one from danger rating
    });

    testWidgets('should show negative danger rating correctly',
        (WidgetTester tester) async {
      // Arrange
      const char1 = CombatStatsData(
        characterId: 1,
        characterName: 'Test Character',
        kills: 30,
        deaths: 50,
        iskDestroyed: 3000000000.0,
        iskLost: 5000000000.0,
      );

      const stats = AggregateCombatStats(
        totalKills: 30,
        totalDeaths: 50,
        totalIskDestroyed: 3000000000.0,
        totalIskLost: 5000000000.0,
        characterStats: [char1],
      );

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCharacterCombatStatsProvider.overrideWith(
              (ref) => Future.value(stats),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: CombatStatsCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('20'), findsOneWidget); // Danger rating (abs value)
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget); // Negative danger rating
    });
  });
}
