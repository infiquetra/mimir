import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/intel/data/intel_providers.dart';
import 'package:mimir/features/intel/data/zkillboard_client.dart';
import 'package:mimir/features/intel/domain/killmail_models.dart';
import 'package:mimir/features/intel/presentation/kill_feed_screen.dart';
import 'package:mimir/features/intel/presentation/widgets/killmail_card.dart';

import '../../test_utils/test_app.dart';

/// Jita's real solar system ID, used throughout as the watched system.
const int jitaSystemId = 30000142;

/// A [ZKillboardClient] that emits killmails on demand instead of over the
/// network.
///
/// Emission is driven explicitly by [emit] so tests never depend on timers or
/// socket scheduling, and [lastSubscription] records the channel filters that
/// were requested so they can be asserted on.
class MockZKillboardClient implements ZKillboardClient {
  final StreamController<ZKillmail> _controller =
      StreamController<ZKillmail>.broadcast();

  /// Channel filters passed to the most recent [connectWebSocket] call.
  ({
    List<int>? systems,
    List<int>? regions,
    List<int>? corporations,
    List<int>? alliances,
    List<int>? characters,
  })?
  lastSubscription;

  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Stream<ZKillmail> get kills => _controller.stream;

  @override
  Future<void> connectWebSocket({
    List<int>? systems,
    List<int>? regions,
    List<int>? corporations,
    List<int>? alliances,
    List<int>? characters,
  }) async {
    connectCalls++;
    lastSubscription = (
      systems: systems,
      regions: regions,
      corporations: corporations,
      alliances: alliances,
      characters: characters,
    );
  }

  /// Pushes [killmail] to every attached listener.
  void emit(ZKillmail killmail) {
    _controller.add(killmail);
  }

  @override
  Future<void> startRedisQPolling() async {}

  @override
  void disconnect() {
    disconnectCalls++;
  }

  @override
  void dispose() {
    disconnect();
    _controller.close();
  }
}

ZKillmail _testKillmail() {
  return ZKillmail(
    killmailId: 123456789,
    killmailTime: DateTime.utc(2026, 5, 20, 18, 30),
    solarSystemId: jitaSystemId,
    victim: KillmailVictim(
      characterId: 90000001,
      characterName: 'Test Victim',
      corporationId: 98000001,
      shipTypeId: 603, // Merlin
      shipTypeName: 'Merlin',
      damageTaken: 500,
    ),
    attackers: [
      KillmailAttacker(
        characterId: 90000002,
        characterName: 'Test Attacker',
        corporationId: 98000002,
        shipTypeId: 603,
        damageDone: 500,
        finalBlow: true,
      ),
    ],
    totalValue: 1000.0,
    zkbInfo: ZkbInfo(
      locationId: jitaSystemId,
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
  );
}

/// Seeds the universe-name cache so `KillmailCard` resolves IDs locally instead
/// of reaching for ESI.
Future<void> _seedNames(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.universeNames)
      .insertOnConflictUpdate(
        UniverseNamesCompanion.insert(
          id: const drift.Value(jitaSystemId),
          name: 'Jita',
          category: 'solar_system',
          lastUpdated: now,
        ),
      );
  await db
      .into(db.universeNames)
      .insertOnConflictUpdate(
        UniverseNamesCompanion.insert(
          id: const drift.Value(603),
          name: 'Merlin',
          category: 'inventory_type',
          lastUpdated: now,
        ),
      );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('KillFeedScreen Integration Test (Mock Feed)', () {
    late MockZKillboardClient mockClient;

    setUp(() {
      mockClient = MockZKillboardClient();
    });

    tearDown(() {
      mockClient.dispose();
    });

    // `KillFeedScreen` shows an indeterminate spinner while the feed is empty,
    // so `pumpAndSettle` would never return. Every wait here is an explicit
    // bounded pump instead.
    Future<void> pumpUntilFeedRenders(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(KillmailCard).evaluate().isNotEmpty) return;
      }
    }

    testWidgets(
      'empty feed shows the waiting state and the watch-list banner',
      (tester) async {
        await tester.pumpWidget(
          TestApp(
            providerOverrides: [
              zkillboardClientProvider.overrideWithValue(mockClient),
            ],
            setupDatabase: (db) async {
              await _seedNames(db);
              await db
                  .into(db.watchList)
                  .insert(
                    WatchListCompanion.insert(
                      id: 'system_$jitaSystemId',
                      watchType: 'system',
                      entityId: jitaSystemId,
                      targetName: 'Jita',
                      reason: 'Trade hub',
                      addedAt: DateTime.now(),
                    ),
                  );
            },
            home: const KillFeedScreen(),
          ),
        );

        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(
          find.text('Waiting for killmails...'),
          findsOneWidget,
          reason: 'An empty feed must render its waiting state',
        );

        // The banner must name the watched entity, never show its raw ID.
        expect(find.textContaining('Watching 1 entities'), findsOneWidget);
        expect(
          find.textContaining('$jitaSystemId'),
          findsNothing,
          reason: 'Raw EVE IDs must never be surfaced to the user',
        );
      },
    );

    testWidgets('connects to feed, caches killmails, and renders them', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          providerOverrides: [
            zkillboardClientProvider.overrideWithValue(mockClient),
          ],
          setupDatabase: _seedNames,
          home: const KillFeedScreen(),
        ),
      );

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final container = ProviderScope.containerOf(
        tester.element(find.byType(KillFeedScreen)),
      );
      final intelRepo = container.read(intelRepositoryProvider);

      // Bridge the client to the repository the same way IntelAlertService does
      // in production.
      final subscription = mockClient.kills.listen(intelRepo.cacheKillmail);
      addTearDown(subscription.cancel);

      await mockClient.connectWebSocket(systems: [jitaSystemId]);

      expect(mockClient.connectCalls, 1);
      expect(
        mockClient.lastSubscription?.systems,
        [jitaSystemId],
        reason: 'Watched systems must be forwarded as channel filters',
      );

      mockClient.emit(_testKillmail());
      await pumpUntilFeedRenders(tester);

      expect(
        find.byType(KillmailCard),
        findsOneWidget,
        reason: 'A cached killmail must render as a card',
      );

      // The card resolves names through the seeded cache, not raw IDs.
      expect(find.text('Jita'), findsWidgets);
      expect(find.text('Merlin'), findsWidgets);
      expect(find.text('Test Victim'), findsOneWidget);

      // And it really landed in Drift, which is the source of truth the screen
      // reads from.
      final persisted = await intelRepo.getRecentKills(
        since: DateTime.utc(2026, 5, 20),
      );
      expect(persisted, hasLength(1));
      expect(persisted.single.killmailId, 123456789);
      expect(persisted.single.solarSystemId, jitaSystemId);
    });

    testWidgets('disconnecting the client leaves cached killmails readable', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          providerOverrides: [
            zkillboardClientProvider.overrideWithValue(mockClient),
          ],
          setupDatabase: (db) async {
            await _seedNames(db);
          },
          home: const KillFeedScreen(),
        ),
      );

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final container = ProviderScope.containerOf(
        tester.element(find.byType(KillFeedScreen)),
      );
      final intelRepo = container.read(intelRepositoryProvider);

      await intelRepo.cacheKillmail(_testKillmail());
      mockClient.disconnect();
      await pumpUntilFeedRenders(tester);

      expect(mockClient.disconnectCalls, 1);
      expect(
        find.byType(KillmailCard),
        findsOneWidget,
        reason: 'Cached killmails survive the socket going away',
      );
    });
  });
}
