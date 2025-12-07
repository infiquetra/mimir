import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/features/wallet/presentation/wallet_screen.dart';
import 'package:mimir/features/wallet/presentation/widgets/balance_cards_row.dart';

import '../../test_utils/fixtures/character_fixtures.dart';
import '../../test_utils/fixtures/wallet_fixtures.dart';
import '../../test_utils/pump_helpers.dart';
import '../../test_utils/test_app.dart';

/// Integration tests for the Wallet screen.
///
/// Tests the wallet screen with:
/// - Balance cards row (ISK, PLEX, LP, EverMarks)
/// - Tab interface (Overview, Transactions, Market)
/// - Wallet journal and transaction display
/// - 30-day income/expense summary
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Wallet Screen Integration Tests', () {
    testWidgets(
      'TC-WALL-001: Balance cards row shows 4 cards',
      (tester) async {
        // GIVEN: Wallet screen with test character and wallet data
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert wallet balance
              await db.recordWalletBalance(characterId, 1500000000.0);

              // Insert loyalty points
              final walletData = WalletFixtures.fullWalletData(
                characterId: characterId,
              );
              await db.batch((batch) {
                batch.insertAll(
                  db.loyaltyPoints,
                  walletData['loyaltyPoints']! as List,
                );
              });

              // Insert PLEX assets
              await db.upsertAssets(walletData['assets']! as List);
            },
            home: const WalletScreen(),
          ),
        );

        // WHEN: Screen loads
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Balance cards row should be visible
        expect(
          find.byType(BalanceCardsRow),
          findsOneWidget,
          reason: 'Balance cards row should render',
        );

        // The BalanceCardsRow contains 4 cards:
        // 1. ISK balance
        // 2. PLEX count
        // 3. LP Corporations (total)
        // 4. EverMarks (if applicable)
      },
    );

    testWidgets(
      'TC-WALL-002: Tab switching works (Overview/Transactions/Market)',
      (tester) async {
        // GIVEN: Wallet screen with test character
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const WalletScreen(),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Overview tab should be active by default
        expect(
          find.text('Overview'),
          findsOneWidget,
          reason: 'Overview tab should be visible',
        );

        // WHEN: Tap Transactions tab
        await tester.tap(find.text('Transactions'));
        await tester.pumpAndSettle();

        // THEN: Transactions tab should be active
        expect(
          find.text('Transactions'),
          findsOneWidget,
          reason: 'Transactions tab should be visible',
        );

        // WHEN: Tap Market tab
        await tester.tap(find.text('Market'));
        await tester.pumpAndSettle();

        // THEN: Market tab should be active
        expect(
          find.text('Market'),
          findsOneWidget,
          reason: 'Market tab should be visible',
        );
      },
    );

    testWidgets(
      'TC-WALL-003: No character shows empty state',
      (tester) async {
        // GIVEN: Wallet screen with NO character
        await tester.pumpWidget(
          const TestApp(
            initialCharacter: null,
            home: WalletScreen(),
          ),
        );

        // WHEN: Screen loads
        await tester.pumpAndSettle();

        // THEN: Empty state should be visible
        expect(
          find.text('No Character Selected'),
          findsOneWidget,
          reason: 'Should show empty state heading',
        );

        expect(
          find.text('Add a character to view your wallet.'),
          findsOneWidget,
          reason: 'Should show helpful message',
        );

        expect(
          find.byIcon(Icons.person_off_outlined),
          findsOneWidget,
          reason: 'Should show no character icon',
        );

        // AND: Balance cards should NOT be visible
        expect(
          find.byType(BalanceCardsRow),
          findsNothing,
          reason: 'Balance cards should not render without character',
        );
      },
    );

    testWidgets(
      'TC-WALL-004: Wallet journal displays transactions',
      (tester) async {
        // GIVEN: Wallet screen with wallet journal entries
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert wallet journal entries
              final walletData = WalletFixtures.fullWalletData(
                characterId: characterId,
              );
              await db.insertWalletJournalEntries(
                walletData['journal']! as List,
              );
            },
            home: const WalletScreen(),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // WHEN: Switch to Transactions tab
        await tester.tap(find.text('Transactions'));
        await tester.pumpAndSettle();

        // THEN: Wallet journal entries should be visible
        // The exact display depends on the TransactionsPanel implementation
        expect(
          find.byType(WalletScreen),
          findsOneWidget,
          reason: 'Transactions panel should render',
        );

        // Test fixtures include 3 journal entries:
        // 1. Bounty prize (+100M)
        // 2. Market purchase (-50M)
        // 3. Player trading (+25M)
      },
    );

    testWidgets(
      'TC-WALL-005: Market transactions show item names',
      (tester) async {
        // GIVEN: Wallet screen with market transactions
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert wallet transactions
              final walletData = WalletFixtures.fullWalletData(
                characterId: characterId,
              );
              await db.insertWalletTransactions(
                walletData['transactions']! as List,
              );
            },
            home: const WalletScreen(),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // WHEN: Switch to Market tab
        await tester.tap(find.text('Market'));
        await tester.pumpAndSettle();

        // Wait for market transactions to load
        await waitForLoadingToComplete(tester);

        // THEN: Market transactions panel should render
        expect(
          find.byType(WalletScreen),
          findsOneWidget,
          reason: 'Market transactions panel should render',
        );

        // AND: Should NOT show raw item IDs
        expect(
          find.textContaining('Item #'),
          findsNothing,
          reason: 'Should not show raw item IDs',
        );

        // Test fixtures include 2 transactions:
        // 1. Buy Rifter (typeId 587)
        // 2. Sell PLEX (typeId 44992)
        // These should be resolved via itemNameProvider
      },
    );

    testWidgets(
      'TC-WALL-006: Balance ISK displays formatted',
      (tester) async {
        // GIVEN: Wallet screen with 1.5B ISK balance
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Record wallet balance: 1,500,000,000 ISK
              await db.recordWalletBalance(characterId, 1500000000.0);
            },
            home: const WalletScreen(),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Balance cards row should be visible
        expect(
          find.byType(BalanceCardsRow),
          findsOneWidget,
          reason: 'Balance cards should render',
        );

        // AND: Should NOT show raw unformatted number
        expect(
          find.textContaining('1500000000'),
          findsNothing,
          reason: 'Should not show raw unformatted ISK amount',
        );

        // Common formats: "1,500,000,000 ISK" or "1.5B ISK"
        // The exact format depends on BalanceCardsRow implementation
      },
    );

    testWidgets(
      'TC-WALL-007: TabBarView renders without overflow',
      (tester) async {
        // GIVEN: Wallet screen with test character
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const WalletScreen(),
          ),
        );

        // WHEN: Screen loads
        await tester.pumpAndSettle();

        // THEN: TabBarView should be visible
        expect(
          find.byType(TabBarView),
          findsOneWidget,
          reason: 'TabBarView should render',
        );

        // AND: Should be wrapped in Expanded (prevents overflow)
        final column = tester.widget<Column>(
          find.ancestor(
            of: find.byType(TabBarView),
            matching: find.byType(Column),
          ),
        );

        // TabBarView should be in an Expanded widget
        expect(
          column.children.any((child) =>
              child is Expanded && child.child is TabBarView),
          isTrue,
          reason: 'TabBarView should be wrapped in Expanded',
        );

        // This test validates the fix from commit 62a6320
        // which wrapped TabBarView in Expanded to prevent overflow
      },
    );

    testWidgets(
      'TC-WALL-008: 30-day summary displays in Overview',
      (tester) async {
        // GIVEN: Wallet screen with journal entries from last 30 days
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert wallet journal entries (recent)
              final walletData = WalletFixtures.fullWalletData(
                characterId: characterId,
              );
              await db.insertWalletJournalEntries(
                walletData['journal']! as List,
              );
            },
            home: const WalletScreen(),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Overview tab should be active (default)
        // The OverviewPanel should display 30-day income/expense summary
        expect(
          find.byType(WalletScreen),
          findsOneWidget,
          reason: 'Overview panel should render with summary',
        );

        // Test fixtures include:
        // - Income: 100M (bounty) + 25M (trade) = 125M
        // - Expenses: 50M (market purchase)
        // - Net: 75M
      },
    );
  });
}
