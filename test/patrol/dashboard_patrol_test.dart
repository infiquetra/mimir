import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:mimir/core/window/standalone_dashboard_screen.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/combat_stats_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/combined_wealth_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/fleet_status_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/quick_actions_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/training_overview_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/training_timeline_card.dart';
import 'package:mimir/features/dashboard/presentation/widgets/cards/wallet_trends_card.dart';
import 'package:mimir/features/dashboard/data/combat_providers.dart';
import 'package:mimir/features/dashboard/data/fleet_providers.dart';

import '../../integration_test/test_utils/fixtures/character_fixtures.dart';
import '../../integration_test/test_utils/fixtures/skill_fixtures.dart';
import '../../integration_test/test_utils/fixtures/wallet_fixtures.dart';
import '../../integration_test/test_utils/test_app.dart';

void main() {
  patrolWidgetTest(
    'Dashboard E2E - verifies all cards load and can be interacted with',
    ($) async {
      final characterId = 12345678;

      await $.pumpWidget(
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
              (walletData['journal']! as List).cast(),
            );
            await db.recordWalletBalance(characterId, 1500000000.0);
          },
          providerOverrides: [
            allCharacterCombatStatsProvider.overrideWith((ref) async => const AggregateCombatStats(
              totalKills: 100,
              totalDeaths: 50,
              totalIskDestroyed: 1000000000.0,
              totalIskLost: 500000000.0,
              characterStats: [],
            )),
            allCharacterFleetStatusProvider.overrideWith((ref) async => const AggregateFleetStatus(
              totalCharacters: 1,
              onlineCharacters: 1,
              offlineCharacters: 0,
              characterStatuses: [],
            )),
          ],
          home: const StandaloneDashboardScreen(),
        ),
      );

      // Wait for the main cards to become visible
      await $(CombinedWealthCard).waitUntilVisible();

      // Verify top cards are visible
      expect($(CombinedWealthCard).exists, true);
      expect($(TrainingOverviewCard).exists, true);
      expect($(QuickActionsCard).exists, true);
      
      // Scroll to find elements further down the dashboard
      await $(WalletTrendsCard).scrollTo();
      expect($(WalletTrendsCard).exists, true);
      
      await $(TrainingTimelineCard).scrollTo();
      expect($(TrainingTimelineCard).exists, true);
      
      await $(CombatStatsCard).scrollTo();
      expect($(CombatStatsCard).exists, true);
      
      // Verify we don't show raw skill IDs
      expect($('Skill #3301').exists, false);

      // Unmount the TestApp to trigger ProviderScope disposal and cancel streams
      await $.pumpWidget(Container());
      
      // Pump to clear any microtasks/timers scheduled by Drift's stream closure
      await $.pump(const Duration(milliseconds: 100));
    },
  );
}
