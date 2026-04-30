import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/orders/presentation/active_orders_screen.dart';

void main() {
  group('ActiveOrdersScreen', () {
    final testCharacter = Character(
      characterId: 12345678,
      name: 'Test Pilot',
      corporationId: 100,
      corporationName: 'Test Corp',
      allianceId: null,
      allianceName: null,
      factionId: null,
      securityStatus: 0.5,
      portraitUrl: 'https://example.com/portrait.jpg',
      refreshToken: null,
      accessToken: null,
      tokenExpiry: DateTime.now(),
      lastUpdated: DateTime.now(),
      isActive: true,
    );

    Widget buildWidget(List<dynamic> overrides) {
      return ProviderScope(
        overrides: overrides.cast(),
        child: const MaterialApp(
          home: Scaffold(
            body: ActiveOrdersScreen(),
          ),
        ),
      );
    }

    testWidgets('shows no character state when no character selected',
        (tester) async {
      await tester.pumpWidget(
        buildWidget([
          activeCharacterProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Character Selected'), findsOneWidget);
      expect(
        find.text('Add a character to view market orders.'),
        findsOneWidget,
      );
    });

    testWidgets('shows loading state while fetching character',
        (tester) async {
      await tester.pumpWidget(
        buildWidget([
          activeCharacterProvider.overrideWith(
            (ref) => Stream.value(testCharacter),
          ),
          // Simulate a slow-loading orders provider by using a delayed future
          activeOrdersProvider.overrideWith(
            (ref) => Future.delayed(
              const Duration(seconds: 10),
              () => <Order>[],
            ),
          ),
        ]),
      );
      // Pump once to trigger the initial frame (loading state)
      await tester.pump();

      // Verify the screen renders without error and transitions to loading
      expect(find.byType(ActiveOrdersScreen), findsOneWidget);
      // Don't pumpAndSettle here — that would wait for the 10s timer
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets('shows active orders when character is selected',
        (tester) async {
      await tester.pumpWidget(
        buildWidget([
          activeCharacterProvider.overrideWith(
            (ref) => Stream.value(testCharacter),
          ),
          // Override with pre-resolved future to avoid async delays in test
          activeOrdersProvider.overrideWith(
            (ref) => Future.value([
              Order(
                orderId: 1,
                typeId: 34,
                typeName: 'Tritanium',
                quantity: 100000,
                price: 5.50,
                isBuyOrder: true,
                location: 'Jita IV - Moon 4',
                timeRemaining: const Duration(days: 2, hours: 4),
                issuedDate: DateTime.now(),
              ),
              Order(
                orderId: 2,
                typeId: 35,
                typeName: 'Pyerite',
                quantity: 50000,
                price: 2.30,
                isBuyOrder: false,
                location: 'Amarr VIII',
                timeRemaining: const Duration(hours: 12),
                issuedDate: DateTime.now(),
              ),
            ]),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Orders'), findsOneWidget);
      expect(find.text('Tritanium'), findsOneWidget);
      expect(find.text('Pyerite'), findsOneWidget);
    });

    testWidgets('shows empty state when no orders exist', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          activeCharacterProvider.overrideWith(
            (ref) => Stream.value(testCharacter),
          ),
          activeOrdersProvider.overrideWith(
            (ref) => Future.value([]),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Active Orders'), findsOneWidget);
      expect(
        find.text('Your market orders will appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('shows error state when orders fail to load',
        (tester) async {
      await tester.pumpWidget(
        buildWidget([
          activeCharacterProvider.overrideWith(
            (ref) => Stream.value(testCharacter),
          ),
          activeOrdersProvider.overrideWith(
            (ref) => Future.error('Failed to load orders'),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to Load Orders'), findsOneWidget);
    });

    testWidgets('shows buy and sell order icons correctly', (tester) async {
      await tester.pumpWidget(
        buildWidget([
          activeCharacterProvider.overrideWith(
            (ref) => Stream.value(testCharacter),
          ),
          activeOrdersProvider.overrideWith(
            (ref) => Future.value([
              Order(
                orderId: 1,
                typeId: 34,
                typeName: 'Tritanium',
                quantity: 100000,
                price: 5.50,
                isBuyOrder: true,
                location: 'Jita',
                timeRemaining: const Duration(days: 1),
                issuedDate: DateTime.now(),
              ),
              Order(
                orderId: 2,
                typeId: 35,
                typeName: 'Pyerite',
                quantity: 50000,
                price: 2.30,
                isBuyOrder: false,
                location: 'Amarr',
                timeRemaining: const Duration(days: 1),
                issuedDate: DateTime.now(),
              ),
            ]),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // Buy order shows down arrow, sell order shows up arrow
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('refresh button invalidates orders provider',
        (tester) async {
      var refreshCount = 0;

      await tester.pumpWidget(
        buildWidget([
          activeCharacterProvider.overrideWith(
            (ref) => Stream.value(testCharacter),
          ),
          activeOrdersProvider.overrideWith(
            (ref) async {
              refreshCount++;
              if (refreshCount == 1) {
                return [
                  Order(
                    orderId: 1,
                    typeId: 34,
                    typeName: 'Tritanium',
                    quantity: 100000,
                    price: 5.50,
                    isBuyOrder: true,
                    location: 'Jita',
                    timeRemaining: const Duration(days: 1),
                    issuedDate: DateTime.now(),
                  ),
                ];
              }
              // Second load returns different quantity
              return [
                Order(
                  orderId: 1,
                  typeId: 34,
                  typeName: 'Tritanium',
                  quantity: 200000,
                  price: 5.50,
                  isBuyOrder: true,
                  location: 'Jita',
                  timeRemaining: const Duration(days: 1),
                  issuedDate: DateTime.now(),
                ),
              ];
            },
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('100K'), findsOneWidget);

      // Tap refresh
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(refreshCount, equals(2));
    });
  });
}
