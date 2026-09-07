import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/market/data/market_providers.dart';
import 'package:mimir/features/market/presentation/market_overview_screen.dart';

import '../../../../integration_test/test_utils/fixtures/character_fixtures.dart';
import '../../../../integration_test/test_utils/test_app.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

class MockSdeService extends Mock implements SdeService {}

void main() {
  group('MarketOverviewScreen', () {
    testWidgets('renders tabs and handles no character state', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          const TestApp(initialCharacter: null, home: MarketOverviewScreen()),
        );
        // Pump twice to let TestApp initialize and build ProviderScope
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Market Tools'), findsOneWidget);
        expect(find.text('My Orders'), findsOneWidget);
        expect(find.text('Browser'), findsOneWidget);

        // Should show no character state on active orders tab
        await tester.tap(find.text('My Orders'));
        await tester.pumpAndSettle();
        expect(find.text('No Character Selected'), findsOneWidget);

        // Teardown to flush Riverpod/Drift timers
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    testWidgets('shows empty state when character has no orders', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const MarketOverviewScreen(),
          ),
        );

        // Pump to allow TestApp to initialize ProviderScope
        await tester.pump(const Duration(seconds: 1));

        // Override the mock to return empty orders for this specific test
        final mockEsi = getMockEsiClient(tester);
        when(
          () => mockEsi.getCharacterOrders(any()),
        ).thenAnswer((_) async => const EsiResponse(data: [], headers: {}));

        // Tap on 'My Orders'
        await tester.tap(find.text('My Orders'));
        await tester.pumpAndSettle();

        expect(find.text('No Active Orders'), findsOneWidget);

        // Teardown to flush Riverpod/Drift timers
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    testWidgets('renders active orders when database has data', (tester) async {
      await mockNetworkImagesFor(() async {
        final character = CharacterFixtures.testCharacter();

        await tester.pumpWidget(
          TestApp(
            initialCharacter: character,
            setupDatabase: (db) async {
              final now = DateTime.now();
              await db
                  .into(db.marketOrders)
                  .insert(
                    MarketOrder(
                      orderId: 1,
                      characterId: character.characterId.value,
                      typeId: 34, // Tritanium
                      regionId: 10000002, // The Forge
                      locationId: 60003760, // Jita 4-4
                      price: 4.5,
                      volumeRemain: 5000,
                      volumeTotal: 10000,
                      minVolume: 1,
                      isBuyOrder: false,
                      issued: now.subtract(const Duration(days: 1)),
                      duration: 90,
                      range: 'region',
                      isCorporation: false,
                      escrow: 0.0,
                      state: 'active',
                    ),
                  );
            },
            home: const MarketOverviewScreen(),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Tap on 'My Orders'
        await tester.tap(find.text('My Orders'));
        await tester.pumpAndSettle();

        // Verify the order shows up
        expect(find.textContaining('Tritanium'), findsOneWidget);
        expect(find.textContaining('SELL'), findsOneWidget);
        expect(find.textContaining('5000 / 10000'), findsOneWidget);

        // Teardown to flush Riverpod/Drift timers
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    testWidgets('browser search returns results from the bundled SDE', (
      tester,
    ) async {
      await mockNetworkImagesFor(() async {
        // The Browser tab searches the bundled SDE offline, so give it a real
        // in-memory SDE containing Tritanium instead of letting the provider
        // try to import the shipped assets under fake async.
        final sdeDatabase = SdeDatabase.forTesting(NativeDatabase.memory());
        addTearDown(sdeDatabase.close);
        await sdeDatabase.into(sdeDatabase.sdeTypes).insert(
          SdeTypesCompanion.insert(
            typeId: const Value(34),
            typeName: 'Tritanium',
            groupId: 18,
          ),
        );

        final mockSde = MockSdeService();
        when(() => mockSde.database).thenReturn(sdeDatabase);
        when(() => mockSde.initialize()).thenAnswer((_) async {});

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            providerOverrides: [
              sdeServiceProvider.overrideWithValue(mockSde),
            ],
            setupDatabase: (db) async {
              await db
                  .into(db.marketPrices)
                  .insert(
                    MarketPrice(
                      typeId: 34,
                      adjustedPrice: 4.5,
                      averagePrice: 4.6,
                      lastUpdated: DateTime.now(),
                    ),
                  );
            },
            home: const MarketOverviewScreen(),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // We should be on 'Browser' by default
        expect(find.text('Search items by name...'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Tritanium');
        await tester.pump();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // A real result row must appear in the results list, not just the
        // typed text in the field.
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text('Tritanium'),
          ),
          findsOneWidget,
          reason: 'Market Browser must return SDE matches for a query',
        );

        // Selecting it must drive the detail view's selection state.
        await tester.tap(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text('Tritanium'),
          ),
        );
        await tester.pump();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MarketOverviewScreen)),
        );
        expect(container.read(selectedMarketItemProvider)?.typeId, 34);

        // Teardown to flush Riverpod/Drift timers
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });
  });
}
