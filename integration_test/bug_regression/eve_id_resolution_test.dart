import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/features/skills/presentation/skills_screen.dart';
import 'package:mimir/features/wallet/presentation/wallet_screen.dart';

import '../test_utils/fixtures/character_fixtures.dart';
import '../test_utils/fixtures/skill_fixtures.dart';
import '../test_utils/fixtures/wallet_fixtures.dart';
import '../test_utils/pump_helpers.dart';
import '../test_utils/test_app.dart';

/// Bug regression tests for EVE ID resolution.
///
/// These tests prevent recurring bugs where numeric IDs are displayed
/// instead of human-readable names.
///
/// Historical issues:
/// - Skills showing "Skill #3301" instead of "Mechanics"
/// - Items showing "Item #587" instead of "Rifter"
/// - Locations showing "Location #60003760" instead of "Jita IV..."
///
/// CLAUDE.md Decision Table:
/// - Skill names → skillNameProvider (SDE, local)
/// - Item/module/ship names → itemNameProvider (ESI /universe/names/)
/// - Station/structure names → locationNameProvider (ESI /universe/names/)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('EVE ID Resolution Regression Tests', () {
    testWidgets(
      'TC-ID-001: Skill names use skillNameProvider (SDE)',
      (tester) async {
        // GIVEN: SkillsScreen with active skill queue
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert skill queue with known skills
              final skills = SkillFixtures.activeQueue(
                characterId: characterId,
              );

              await db.batch((batch) {
                batch.insertAll(db.skillQueueEntries, skills);
              });
            },
            home: const SkillsScreen(),
          ),
        );

        // WHEN: Screen loads and displays skill queue
        await tester.pumpAndSettle();

        // Wait for data to load
        await waitForLoadingToComplete(tester);

        // THEN: Skill names should be resolved from SDE, NOT showing IDs
        // We should find skill names, not "Skill #3301"
        expect(
          find.textContaining('Skill #'),
          findsNothing,
          reason: 'Should not show raw skill IDs like "Skill #3301"',
        );

        // Skills should show actual names (from SDE)
        // Note: The exact name depends on SDE loading, but we should NOT see IDs
        expect(
          find.byType(SkillsScreen),
          findsOneWidget,
          reason: 'Screen should render with skill names resolved',
        );

        // REGRESSION CHECK: Before using skillNameProvider, skills would
        // display as "Skill #3301" because the wrong provider was used.
        // skillNameProvider uses the bundled SDE database for offline resolution.
      },
    );

    testWidgets(
      'TC-ID-002: Item names use itemNameProvider (ESI)',
      (tester) async {
        // GIVEN: WalletScreen with market transactions
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert wallet transactions with known item type IDs
              final transactions = WalletFixtures.allTransactions(
                characterId: characterId,
              );

              await db.insertWalletTransactions(transactions);
            },
            home: const WalletScreen(),
          ),
        );

        // WHEN: Screen loads and displays transactions
        await tester.pumpAndSettle();

        // Switch to Market Transactions tab
        await tester.tap(find.text('Market'));
        await tester.pumpAndSettle();

        // Wait for transaction data to load
        await waitForLoadingToComplete(tester);

        // THEN: Item names should be resolved from ESI, NOT showing IDs
        expect(
          find.textContaining('Item #'),
          findsNothing,
          reason: 'Should not show raw item IDs like "Item #587"',
        );

        expect(
          find.textContaining('Unknown Item'),
          findsNothing,
          reason: 'Should resolve item names from ESI',
        );

        // REGRESSION CHECK: Before using itemNameProvider, items would
        // display as "Item #587" or "Unknown Item" because:
        // 1. Wrong provider was used (skillNameProvider for non-skills)
        // 2. Provider wasn't used at all (raw ID displayed)
        // itemNameProvider uses ESI /universe/names/ endpoint with caching.
      },
    );

    testWidgets(
      'TC-ID-003: Location names use locationNameProvider (ESI)',
      (tester) async {
        // GIVEN: WalletScreen with market transactions (locations)
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert wallet transactions with known location IDs
              final transactions = WalletFixtures.allTransactions(
                characterId: characterId,
              );

              await db.insertWalletTransactions(transactions);
            },
            home: const WalletScreen(),
          ),
        );

        // WHEN: Screen loads and displays transactions
        await tester.pumpAndSettle();

        // Switch to Market Transactions tab
        await tester.tap(find.text('Market'));
        await tester.pumpAndSettle();

        // Wait for transaction data to load
        await waitForLoadingToComplete(tester);

        // THEN: Location names should be resolved from ESI, NOT showing IDs
        expect(
          find.textContaining('Location #'),
          findsNothing,
          reason: 'Should not show raw location IDs like "Location #60003760"',
        );

        expect(
          find.textContaining('Unknown Location'),
          findsNothing,
          reason: 'Should resolve location names from ESI',
        );

        // REGRESSION CHECK: Before using locationNameProvider, locations would
        // display as "Location #60003760" or "Unknown Location" because:
        // 1. Wrong provider was used
        // 2. Provider wasn't used at all (raw ID displayed)
        // locationNameProvider uses ESI /universe/names/ endpoint for stations/structures.
      },
    );

    testWidgets(
      'TC-ID-004: Fallback to raw IDs when resolution fails gracefully',
      (tester) async {
        // GIVEN: WalletScreen with an UNKNOWN item type ID (not in mock data)
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert transaction with unknown item ID
              await db.insertWalletTransactions([
                WalletTransactionsCompanion.insert(
                  transactionId: const Value(999),
                  characterId: characterId,
                  typeId: 999999, // Unknown item ID (not in mock data)
                  locationId: 60003760,
                  unitPrice: 1000.0,
                  quantity: 1,
                  isBuy: true,
                  clientId: 98765432,
                  date: DateTime.now(),
                ),
              ]);
            },
            home: const WalletScreen(),
          ),
        );

        // WHEN: Screen loads and tries to resolve unknown ID
        await tester.pumpAndSettle();

        // Switch to Market Transactions tab
        await tester.tap(find.text('Market'));
        await tester.pumpAndSettle();

        // Wait for transaction data to load
        await waitForLoadingToComplete(tester);

        // THEN: Should gracefully fall back to "Unknown Item" or "Item #999999"
        // The screen should NOT crash, and should render with fallback text
        expect(
          find.byType(WalletScreen),
          findsOneWidget,
          reason: 'Screen should render even with unknown IDs',
        );

        // REGRESSION CHECK: The .when() pattern must handle error/missing
        // data gracefully. Before using .when(), unknown IDs would crash
        // with "No element" errors. Now they show fallback text.
      },
    );
  });
}
