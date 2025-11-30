import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/dashboard/data/dashboard_providers.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/combined_wealth_card.dart';

void main() {
  group('CombinedWealthCard', () {
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

    final character3 = Character(
      characterId: 3,
      name: 'Character Three',
      corporationId: 300,
      corporationName: 'Corp Three',
      allianceId: null,
      allianceName: null,
      portraitUrl: 'https://example.com/portrait3.jpg',
      refreshToken: null,
      accessToken: null,
      tokenExpiry: DateTime.now(),
      lastUpdated: DateTime.now(),
      isActive: false,
    );

    Widget buildWidget(List<Override> overrides) {
      return ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: Scaffold(
            body: CombinedWealthCard(),
          ),
        ),
      );
    }

    testWidgets('displays total wealth correctly', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1, character2]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({
              1: 10000000.0, // 10M
              2: 5000000.0, // 5M
            }),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Should show total of 15M ISK
      expect(find.text('15,000,000.00 ISK'), findsOneWidget);
    });

    testWidgets('displays per-character breakdown with correct order',
        (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1, character2, character3]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({
              1: 8200000000.0, // 8.2B (54%)
              2: 4100000000.0, // 4.1B (27%)
              3: 2900000000.0, // 2.9B (19%)
            }),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Total should be 15.2B
      expect(find.text('15,200,000,000.00 ISK'), findsOneWidget);

      // Should show all three characters
      expect(find.text('Character One'), findsOneWidget);
      expect(find.text('Character Two'), findsOneWidget);
      expect(find.text('Character Three'), findsOneWidget);

      // Should show compact amounts and percentages
      expect(find.textContaining('8.20B'), findsOneWidget);
      expect(find.textContaining('54%'), findsOneWidget);
      expect(find.textContaining('4.10B'), findsOneWidget);
      expect(find.textContaining('27%'), findsOneWidget);
      expect(find.textContaining('2.90B'), findsOneWidget);
      expect(find.textContaining('19%'), findsOneWidget);
    });

    testWidgets('percentages sum to 100%', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1, character2, character3]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({
              1: 100.0,
              2: 200.0,
              3: 300.0,
            }),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Find all percentage text widgets
      final percentageTexts = tester.widgetList<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('%'),
        ),
      );

      // Extract percentages and verify they sum to 100
      final percentages = percentageTexts
          .map((text) {
            final match = RegExp(r'(\d+)%').firstMatch(text.data!);
            return match != null ? int.parse(match.group(1)!) : 0;
          })
          .where((p) => p > 0)
          .toList();

      final sum = percentages.fold<int>(0, (sum, p) => sum + p);
      expect(sum, equals(100));
    });

    testWidgets('handles single character', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({
              1: 5000000.0,
            }),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      expect(find.text('5,000,000.00 ISK'), findsOneWidget);
      expect(find.text('Character One'), findsOneWidget);
      expect(find.textContaining('100%'), findsOneWidget);
    });

    testWidgets('handles zero balance characters', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1, character2]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({
              1: 1000000.0,
              2: 0.0,
            }),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Should show total
      expect(find.text('1,000,000.00 ISK'), findsOneWidget);

      // Should show both characters
      expect(find.text('Character One'), findsOneWidget);
      expect(find.text('Character Two'), findsOneWidget);

      // Should show 0.00 ISK for Character Two
      expect(find.text('0.00 ISK (0%)'), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.delayed(
              const Duration(milliseconds: 100),
              () => <int, double>{},
            ),
          ),
        ]),
      );

      // Should show loading indicator (shimmer effect from DashboardCard)
      await tester.pump();
      expect(find.byType(CombinedWealthCard), findsOneWidget);

      // Complete the delayed future
      await tester.pumpAndSettle();
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.error('Network error'),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Should show error message
      expect(find.text('Error'), findsOneWidget);
      expect(find.textContaining('Network error'), findsOneWidget);

      // Should show retry button
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button refreshes data', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) {
              callCount++;
              if (callCount == 1) {
                return Future.error('Network error');
              }
              return Future.value({1: 5000000.0});
            },
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Should show error initially
      expect(find.text('Error'), findsOneWidget);

      // Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Should show data after retry
      expect(find.text('5,000,000.00 ISK'), findsOneWidget);
      expect(callCount, equals(2));
    });

    testWidgets('characters sorted by balance (highest first)', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1, character2, character3]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({
              1: 1000000.0, // Lowest
              2: 5000000.0, // Highest
              3: 3000000.0, // Middle
            }),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Find all character name widgets
      final characterNames = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.data != null &&
                  (widget.data == 'Character One' ||
                      widget.data == 'Character Two' ||
                      widget.data == 'Character Three'),
            ),
          )
          .map((widget) => widget.data!)
          .toList();

      // Should be sorted: Character Two (5M), Character Three (3M), Character One (1M)
      expect(characterNames[0], equals('Character Two'));
      expect(characterNames[1], equals('Character Three'));
      expect(characterNames[2], equals('Character One'));
    });

    testWidgets('displays character avatars', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({
              1: 5000000.0,
            }),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Should show character avatar
      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == 'CharacterAvatar',
        ),
        findsOneWidget,
      );
    });

    testWidgets('progress bars reflect correct percentages', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          allCharactersProvider.overrideWith(
            (ref) => Stream.value([character1, character2]),
          ),
          allCharacterBalancesProvider.overrideWith(
            (ref) => Future.value({
              1: 7500000.0, // 75%
              2: 2500000.0, // 25%
            }),
          ),
        ]),
      );

      await tester.pumpAndSettle();

      // Find all LinearProgressIndicator widgets
      final progressIndicators = tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );

      expect(progressIndicators.length, equals(2));

      // First should be 75% (0.75)
      expect(progressIndicators.first.value, closeTo(0.75, 0.01));

      // Second should be 25% (0.25)
      expect(progressIndicators.last.value, closeTo(0.25, 0.01));
    });
  });
}
