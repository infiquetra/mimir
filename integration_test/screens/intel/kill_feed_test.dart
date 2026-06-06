import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/features/intel/domain/intel_alert_service.dart';
import 'package:mimir/features/intel/data/intel_providers.dart';
import 'package:mimir/features/intel/presentation/kill_feed_screen.dart';
import 'package:mimir/features/intel/presentation/widgets/killmail_card.dart';
import '../../test_utils/test_app.dart';

class MockZKillboardClient implements ZKillboardClient {
  final _mockStream = StreamController<ZKillmail>.broadcast();

  @override
  Stream<ZKillmail> get kills => _mockStream.stream;

  @override
  Future<void> connectWebSocket({
    List<int>? systems,
    List<int>? regions,
    List<int>? corporations,
    List<int>? alliances,
    List<int>? characters,
  }) async {
    // Emit a mock killmail immediately
    Future.delayed(const Duration(seconds: 1), () {
      _mockStream.add(ZKillmail(
        killmailId: 123456789,
        killmailTime: DateTime.now(),
        solarSystemId: 30000142, // Jita
        victim: KillmailVictim(
          damageTaken: 500,
          shipTypeId: 603,
          characterId: 1,
          corporationId: 1,
        ),
        attackers: [
          KillmailAttacker(
            damageDone: 500,
            securityStatus: 5.0,
            finalBlow: true,
            characterId: 2,
            corporationId: 2,
            shipTypeId: 603,
          )
        ],
        zkb: ZkbData(
          locationId: 30000142,
          hash: 'mockhash',
          fittedValue: 1000.0,
          droppedValue: 0.0,
          destroyedValue: 1000.0,
          totalValue: 1000.0,
          points: 1,
          npc: false,
          solo: true,
          awox: false,
        ),
      ));
    });
  }

  @override
  Future<void> startRedisQPolling() async {}

  @override
  void disconnect() {
    _mockStream.close();
  }

  @override
  void dispose() {
    disconnect();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('KillFeedScreen Integration Test (Mock Feed)', () {
    testWidgets('connects to feed, saves to DB, and updates UI', (
      tester,
    ) async {
      // Create a test app with an in-memory database
      await tester.pumpWidget(
        TestApp(
          overrides: [
            zkillboardClientProvider.overrideWithValue(MockZKillboardClient()),
          ],
          setupDatabase: (db) async {
            // No initial setup needed, start empty
          },
          home: const KillFeedScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final element = tester.element(find.byType(KillFeedScreen));
      final container = ProviderScope.containerOf(element);
      
      final client = container.read(zkillboardClientProvider);
      final repo = container.read(intelRepositoryProvider);

      client.connectWebSocket();
      final sub = client.kills.listen((kill) {
        repo.cacheKillmail(kill);
      });

      addTearDown(() {
        sub.cancel();
        client.disconnect();
      });

      // Wait for the mock killmail to be emitted and rendered
      bool foundKillmail = false;
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));

        if (find.byType(KillmailCard).evaluate().isNotEmpty) {
          foundKillmail = true;
          break;
        }
      }

      expect(
        foundKillmail,
        isTrue,
        reason: 'Timed out waiting for a live killmail from zKillboard',
      );

      // Verify that at least one KillmailCard is rendered
      expect(find.byType(KillmailCard), findsWidgets);
    });
  });
}
