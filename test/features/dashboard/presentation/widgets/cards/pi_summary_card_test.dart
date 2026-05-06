import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/pi_summary_card.dart';
import 'package:mimir/features/pi/data/pi_providers.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  group('PiSummaryCard', () {
    final now = DateTime.now();

    final colony1 = PlanetaryColony(
      planetId: 40000001,
      characterId: 1,
      planetName: 'Colony One',
      planetType: 'Temperate',
      upgradeLevel: 5,
      numPins: 10,
      lastUpdate: now,
    );

    final colony2 = PlanetaryColony(
      planetId: 40000002,
      characterId: 2,
      planetName: 'Colony Two',
      planetType: 'Barren',
      upgradeLevel: 4,
      numPins: 8,
      lastUpdate: now,
    );

    final activePin = PlanetaryPin(
      id: 1,
      pinId: 101,
      characterId: 1,
      planetId: 40000001,
      typeId: 2500,
      latitude: 1.0,
      longitude: 1.0,
      installTime: now.subtract(const Duration(hours: 1)),
      expiryTime: now.add(const Duration(hours: 2)),
      productTypeId: 2390,
    );

    final idlePin = PlanetaryPin(
      id: 2,
      pinId: 201,
      characterId: 2,
      planetId: 40000002,
      typeId: 2500,
      latitude: 1.0,
      longitude: 1.0,
      installTime: now.subtract(const Duration(days: 2)),
      expiryTime: now.subtract(const Duration(hours: 1)),
      productTypeId: 2390,
    );

    Widget buildWidget({
      required AsyncValue<List<PlanetaryColony>> colonies,
      Map<PlanetPinsArgs, AsyncValue<List<PlanetaryPin>>>? pinsMap,
    }) {
      return ProviderScope(
        overrides: [
          allColoniesProvider.overrideWith((ref) => colonies.when(
                data: (data) => Stream.value(data),
                error: (e, s) => Stream.error(e, s),
                loading: () => const Stream.empty(),
              )),
          if (pinsMap != null)
            ...pinsMap.entries.map((entry) =>
                planetPinsProvider(entry.key).overrideWith((ref) => entry.value.when(
                      data: (data) => Stream.value(data),
                      error: (e, s) => Stream.error(e, s),
                      loading: () => const Stream.empty(),
                    ))),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PiSummaryCard(),
          ),
        ),
      );
    }

    testWidgets('displays loading state', (tester) async {
      await tester.pumpWidget(
        buildWidget(colonies: const AsyncLoading()),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('displays empty state', (tester) async {
      await tester.pumpWidget(
        buildWidget(colonies: const AsyncData([])),
      );
      await tester.pumpAndSettle();

      expect(find.text('No active colonies.'), findsOneWidget);
    });

    testWidgets('displays colonies with status', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          colonies: AsyncData([colony1, colony2]),
          pinsMap: {
            PlanetPinsArgs(characterId: 1, planetId: 40000001): AsyncData([activePin]),
            PlanetPinsArgs(characterId: 2, planetId: 40000002): AsyncData([idlePin]),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Colony One'), findsOneWidget);
      expect(find.text('Colony Two'), findsOneWidget);
      expect(find.text('IDLE'), findsOneWidget);
      // "Extracting" is replaced by the timer text if active, which is hard to predict exactly in tests without fixing time.
      // But we can check if it's NOT IDLE.
    });

    testWidgets('displays error state', (tester) async {
      await tester.pumpWidget(
        buildWidget(colonies: AsyncValue.error('API Error', StackTrace.current)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('API Error'), findsOneWidget);
    });
  });
}
