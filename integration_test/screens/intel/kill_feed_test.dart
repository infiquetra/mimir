import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/core/database/database_providers.dart';
import 'package:mimir/features/intel/domain/intel_alert_service.dart';
import 'package:mimir/features/intel/data/intel_providers.dart';
import 'package:mimir/features/intel/presentation/kill_feed_screen.dart';
import 'package:mimir/features/intel/presentation/widgets/killmail_card.dart';
import '../../test_utils/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('KillFeedScreen Integration Test (Live RedisQ)', () {
    testWidgets('connects to live feed, saves to DB, and updates UI', (tester) async {
      // Create a test app with an in-memory database
      await tester.pumpWidget(
        TestApp(
          setupDatabase: (db) async {
            // No initial setup needed, start empty
          },
          home: Consumer(
            builder: (context, ref, child) {
              // Initialize the alert service to start the live feed
              // For testing the live feed without filters, we manually connect
              final client = ref.read(zkillboardClientProvider);
              final repo = ref.read(intelRepositoryProvider);
              
              // We bypass IntelAlertService's config watcher for the test so we 
              // receive ALL kills and ensure the test passes quickly.
              client.connectWebSocket();
              
              // Forward kills to repo
              final sub = client.kills.listen((kill) {
                repo.cacheKillmail(kill);
              });
              
              // Clean up on dispose
              ref.onDispose(() {
                sub.cancel();
                client.disconnect();
              });
              
              return const KillFeedScreen();
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially shows loading or waiting state
      expect(find.text('Waiting for killmails...'), findsOneWidget);

      // Wait for a live killmail to come through the RedisQ/WebSocket
      // zKillboard is usually very active, we should see one within 15 seconds.
      bool foundKillmail = false;
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        
        if (find.byType(KillmailCard).evaluate().isNotEmpty) {
          foundKillmail = true;
          break;
        }
      }
      
      expect(foundKillmail, isTrue, reason: 'Timed out waiting for a live killmail from zKillboard');
      
      // Verify that at least one KillmailCard is rendered
      expect(find.byType(KillmailCard), findsWidgets);
    });
  });
}
