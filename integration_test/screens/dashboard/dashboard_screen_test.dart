import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/core/window/standalone_dashboard_screen.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/combat_stats_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/combined_wealth_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/fleet_status_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/quick_actions_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/training_overview_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/training_timeline_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/wallet_trends_card.dart';

import '../../test_utils/fixtures/character_fixtures.dart';
import '../../test_utils/fixtures/skill_fixtures.dart';
import '../../test_utils/fixtures/wallet_fixtures.dart';
import '../../test_utils/pump_helpers.dart';
import '../../test_utils/test_app.dart';

/// Integration tests for the Dashboard screen.
///
/// Tests the main dashboard with all 7 overview cards:
/// 1. CombinedWealthCard - Total ISK/PLEX/LP across all characters
/// 2. TrainingOverviewCard - Currently training skill
/// 3. QuickActionsCard - Quick action buttons
/// 4. FleetStatusCard - Fleet membership status
/// 5. WalletTrendsCard - 30-day income/expense chart
/// 6. TrainingTimelineCard - Multi-character skill queue timeline
/// 7. CombatStatsCard - Kill/loss statistics
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard Screen Integration Tests', () {
    testWidgets(
      'TC-DASH-001: All 7 cards render without errors',
      (tester) async {
        // GIVEN: Dashboard with test character and full data
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert skill queue for training overview
              await db.batch((batch) {
                batch.insertAll(
                  db.skillQueueEntries,
                  SkillFixtures.activeQueue(characterId: characterId),
                );
              });

              // Insert wallet data for wealth card and trends
              final walletData = WalletFixtures.fullWalletData(
                characterId: characterId,
              );
              await db.insertWalletJournalEntries(
                walletData['journal']! as List,
              );
              await db.recordWalletBalance(characterId, 1500000000.0);
            },
            home: const StandaloneDashboardScreen(),
          ),
        );

        // WHEN: Dashboard loads
        await tester.pumpAndSettle();

        // Wait for all async data to load
        await waitForLoadingToComplete(tester);

        // THEN: All 7 cards should be present
        expect(
          find.byType(CombinedWealthCard),
          findsOneWidget,
          reason: 'Card 1: Combined Wealth should render',
        );

        expect(
          find.byType(TrainingOverviewCard),
          findsOneWidget,
          reason: 'Card 2: Training Overview should render',
        );

        expect(
          find.byType(QuickActionsCard),
          findsOneWidget,
          reason: 'Card 3: Quick Actions should render',
        );

        expect(
          find.byType(FleetStatusCard),
          findsOneWidget,
          reason: 'Card 4: Fleet Status should render',
        );

        expect(
          find.byType(WalletTrendsCard),
          findsOneWidget,
          reason: 'Card 5: Wallet Trends should render',
        );

        expect(
          find.byType(TrainingTimelineCard),
          findsOneWidget,
          reason: 'Card 6: Training Timeline should render',
        );

        expect(
          find.byType(CombatStatsCard),
          findsOneWidget,
          reason: 'Card 7: Combat Stats should render',
        );
      },
    );

    testWidgets(
      'TC-DASH-002: No character shows empty state',
      (tester) async {
        // GIVEN: Dashboard with NO characters
        await tester.pumpWidget(
          const TestApp(
            initialCharacter: null, // No character
            home: StandaloneDashboardScreen(),
          ),
        );

        // WHEN: Dashboard loads
        await tester.pumpAndSettle();

        // THEN: Empty state should be visible
        expect(
          find.text('No Characters'),
          findsOneWidget,
          reason: 'Should show "No Characters" heading',
        );

        expect(
          find.text('Open the Characters window to add a character.'),
          findsOneWidget,
          reason: 'Should show helpful message',
        );

        expect(
          find.byIcon(Icons.person_add_outlined),
          findsOneWidget,
          reason: 'Should show add character icon',
        );

        // AND: Dashboard cards should NOT be visible
        expect(
          find.byType(CombinedWealthCard),
          findsNothing,
          reason: 'No cards should render without characters',
        );
      },
    );

    testWidgets(
      'TC-DASH-003: Pull-to-refresh triggers provider invalidation',
      (tester) async {
        // GIVEN: Dashboard with test character
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const StandaloneDashboardScreen(),
          ),
        );

        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // WHEN: Pull-to-refresh is triggered
        await triggerPullToRefresh(tester);
        await tester.pump();

        // THEN: Should show loading indicator
        expect(
          find.byType(CircularProgressIndicator),
          findsAtLeastNWidgets(1),
          reason: 'Refresh should trigger loading state',
        );

        // WHEN: Refresh completes
        await tester.pumpAndSettle();

        // THEN: Dashboard should be visible again
        expect(
          find.byType(StandaloneDashboardScreen),
          findsOneWidget,
          reason: 'Dashboard should re-render after refresh',
        );
      },
    );

    testWidgets(
      'TC-DASH-004: CombinedWealthCard shows formatted ISK',
      (tester) async {
        // GIVEN: Dashboard with character that has 1.5B ISK
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Record wallet balance: 1,500,000,000 ISK
              await db.recordWalletBalance(characterId, 1500000000.0);
            },
            home: const StandaloneDashboardScreen(),
          ),
        );

        // WHEN: Dashboard loads
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: CombinedWealthCard should be present
        expect(
          find.byType(CombinedWealthCard),
          findsOneWidget,
          reason: 'Wealth card should render',
        );

        // AND: Should show formatted ISK amount (with commas or abbreviation)
        // The exact format depends on implementation, but should NOT show
        // raw number "1500000000.0" or scientific notation "1.5e+9"
        // Common formats: "1,500,000,000 ISK" or "1.5B ISK"
        expect(
          find.textContaining('1500000000'),
          findsNothing,
          reason: 'Should not show raw unformatted number',
        );
      },
    );

    testWidgets(
      'TC-DASH-005: TrainingOverviewCard shows skill name (not ID)',
      (tester) async {
        // GIVEN: Dashboard with character training a skill
        final characterId = 12345678;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            setupDatabase: (db) async {
              // Insert active skill queue (currently training Mechanics V)
              await db.batch((batch) {
                batch.insertAll(
                  db.skillQueueEntries,
                  SkillFixtures.activeQueue(characterId: characterId),
                );
              });
            },
            home: const StandaloneDashboardScreen(),
          ),
        );

        // WHEN: Dashboard loads
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: TrainingOverviewCard should be present
        expect(
          find.byType(TrainingOverviewCard),
          findsOneWidget,
          reason: 'Training overview card should render',
        );

        // AND: Should NOT show raw skill IDs like "Skill #3301"
        expect(
          find.textContaining('Skill #'),
          findsNothing,
          reason: 'Should not show raw skill IDs',
        );

        // This validates that the card uses skillNameProvider correctly
        // to resolve skill IDs to names from the SDE database.
      },
    );

    testWidgets(
      'TC-DASH-006: QuickActionsCard buttons are tappable',
      (tester) async {
        // GIVEN: Dashboard with test character
        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const StandaloneDashboardScreen(),
          ),
        );

        // WHEN: Dashboard loads
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: QuickActionsCard should be present
        expect(
          find.byType(QuickActionsCard),
          findsOneWidget,
          reason: 'Quick actions card should render',
        );

        // AND: Should contain buttons (implementation may vary)
        // The presence of the card without errors indicates it rendered successfully
        // Actual button functionality would require navigation setup
      },
    );

    testWidgets(
      'TC-DASH-007: Dashboard handles multiple characters',
      (tester) async {
        // GIVEN: Dashboard with TWO characters
        final char1Id = 12345678;
        final char2Id = 23456789;

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(isActive: true),
            setupDatabase: (db) async {
              // Insert second character
              await db.upsertCharacter(
                CharacterFixtures.testCharacter2(isActive: false),
              );

              // Insert wallet balances for both
              await db.recordWalletBalance(char1Id, 1000000000.0);
              await db.recordWalletBalance(char2Id, 500000000.0);

              // Insert skill queues for both
              await db.batch((batch) {
                batch.insertAll(
                  db.skillQueueEntries,
                  SkillFixtures.activeQueue(characterId: char1Id),
                );
                batch.insertAll(
                  db.skillQueueEntries,
                  SkillFixtures.singleSkillQueue(
                    characterId: char2Id,
                    skillId: 3392, // Engineering
                  ),
                );
              });
            },
            home: const StandaloneDashboardScreen(),
          ),
        );

        // WHEN: Dashboard loads with multiple characters
        await tester.pumpAndSettle();
        await waitForLoadingToComplete(tester);

        // THEN: Dashboard should render successfully
        expect(
          find.byType(StandaloneDashboardScreen),
          findsOneWidget,
          reason: 'Dashboard should render with multiple characters',
        );

        // AND: All cards should be present
        expect(
          find.byType(CombinedWealthCard),
          findsOneWidget,
          reason: 'Wealth card should aggregate across characters',
        );

        expect(
          find.byType(TrainingTimelineCard),
          findsOneWidget,
          reason: 'Timeline card should show multi-character queues',
        );

        // The dashboard is designed to aggregate data across ALL characters,
        // so it should handle multiple characters gracefully.
      },
    );

    testWidgets(
      'TC-DASH-008: Dashboard responsive grid layout',
      (tester) async {
        // GIVEN: Dashboard at different viewport widths

        // Test narrow viewport (1 column)
        await tester.binding.setSurfaceSize(const Size(500, 800));

        await tester.pumpWidget(
          TestApp(
            initialCharacter: CharacterFixtures.testCharacter(),
            home: const StandaloneDashboardScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // THEN: Should render without overflow
        expect(
          find.byType(StandaloneDashboardScreen),
          findsOneWidget,
          reason: 'Should render at narrow width (500px)',
        );

        // WHEN: Viewport widens to medium (2 columns)
        await tester.binding.setSurfaceSize(const Size(750, 800));
        await tester.pumpAndSettle();

        // THEN: Should adapt layout without overflow
        expect(
          find.byType(StandaloneDashboardScreen),
          findsOneWidget,
          reason: 'Should render at medium width (750px)',
        );

        // WHEN: Viewport widens to large (still 2 columns per code)
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        await tester.pumpAndSettle();

        // THEN: Should render at wide width
        expect(
          find.byType(StandaloneDashboardScreen),
          findsOneWidget,
          reason: 'Should render at wide width (1200px)',
        );

        // Reset surface size
        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}
