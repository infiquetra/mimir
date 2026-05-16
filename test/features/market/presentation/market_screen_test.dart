import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/market/presentation/market_overview_screen.dart';

import '../../../../integration_test/test_utils/fixtures/character_fixtures.dart';
import '../../../../integration_test/test_utils/test_app.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  group('MarketOverviewScreen', () {
    testWidgets('renders tabs and handles no character state', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          const TestApp(
            initialCharacter: null,
            home: MarketOverviewScreen(),
          ),
        );
        // Pump twice to let TestApp initialize and build ProviderScope
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Market Tools'), findsOneWidget);
        expect(find.text('Active Orders'), findsOneWidget);
        expect(find.text('Price Checker'), findsOneWidget);

        // Should show no character state on active orders tab
        expect(find.text('No Character Selected'), findsOneWidget);

        // Teardown to flush Riverpod/Drift timers
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    testWidgets('shows empty state when character has no orders', (tester) async {
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
        when(() => mockEsi.getCharacterOrders(any())).thenAnswer(
          (_) async => const EsiResponse(data: [], headers: {}),
        );
        
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
              await db.into(db.marketOrders).insert(
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

        // Verify the order shows up
        expect(find.textContaining('Tritanium'), findsOneWidget);
        expect(find.textContaining('SELL'), findsOneWidget);
        expect(find.textContaining('5000 / 10000'), findsOneWidget);

        // Teardown to flush Riverpod/Drift timers
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    testWidgets('price checker search functions', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              await db.into(db.marketPrices).insert(
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

        // Tap on the Price Checker tab
        await tester.tap(find.text('Price Checker'));
        await tester.pumpAndSettle();

        expect(find.text('Search for an Item'), findsOneWidget);

        // Search for an item
        await tester.enterText(find.byType(TextField), '34');
        await tester.tap(find.text('Search'));
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.textContaining('Tritanium'), findsOneWidget);
        expect(find.textContaining('Adjusted Price'), findsOneWidget);
        expect(find.textContaining('Average Price'), findsOneWidget);

        // Teardown to flush Riverpod/Drift timers
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });
  });
}
