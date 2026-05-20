import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/logging/logger.dart';
import '../data/intel_providers.dart';
import '../data/intel_repository.dart';
import '../data/zkillboard_client.dart';

final intelAlertServiceProvider = Provider<IntelAlertService>((ref) {
  final service = IntelAlertService(
    client: ref.watch(zkillboardClientProvider),
    repo: ref.watch(intelRepositoryProvider),
  );
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

class IntelAlertService {
  final ZKillboardClient client;
  final IntelRepository repo;
  
  StreamSubscription? _configSub;
  StreamSubscription? _killmailSub;
  
  List<WatchListData> _currentWatchList = [];

  bool _isInitialized = false;

  IntelAlertService({
    required this.client,
    required this.repo,
  });

  void initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    Log.d('INTEL', 'IntelAlertService.initialize() - START');
    
    // Make sure local_notifier is initialized
    try {
      await localNotifier.setup(
        appName: 'Mimir Intel',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      Log.i('INTEL', 'local_notifier setup successfully');
    } catch (e, stack) {
      Log.e('INTEL', 'Failed to initialize local_notifier', e, stack);
    }

    // Watch config from DB and reconnect WebSocket on change
    Log.d('INTEL', 'Subscribing to repo.watchConfig()');
    _configSub = repo.watchConfig().listen((config) {
      Log.i('INTEL', 'Watch config changed. ${config.length} items watched.');
      _currentWatchList = config;
      _reconnectWithConfig(config);
    });

    // Listen to incoming kills to cache them and check for alerts
    Log.d('INTEL', 'Subscribing to zKillboard client.kills stream');
    _killmailSub = client.kills.listen((kill) async {
      Log.d('INTEL', 'Received live killmail: ${kill.killmailId}');
      try {
        // 1. Cache to DB
        await repo.cacheKillmail(kill);
        
        // 2. Check for alerts
        _checkForAlerts(kill);
      } catch (e, stack) {
        Log.e('INTEL', 'Error processing killmail ${kill.killmailId}', e, stack);
      }
    });
  }

  void _reconnectWithConfig(List<WatchListData> config) {
    Log.d('INTEL', 'Disconnecting old zKillboard client connection...');
    client.disconnect();
    
    if (config.isEmpty) {
      Log.i('INTEL', 'No entities in WatchList. Client disconnected.');
      return; // Nothing to watch
    }

    final systems = config.where((w) => w.watchType == 'system').map((w) => w.entityId).toList();
    final characters = config.where((w) => w.watchType == 'character').map((w) => w.entityId).toList();
    final corporations = config.where((w) => w.watchType == 'corporation').map((w) => w.entityId).toList();
    final alliances = config.where((w) => w.watchType == 'alliance').map((w) => w.entityId).toList();

    Log.i('INTEL', 'Reconnecting zKillboard client. systems=${systems.length}, chars=${characters.length}, corps=${corporations.length}, alliances=${alliances.length}');

    client.connectWebSocket(
      systems: systems.isNotEmpty ? systems : null,
      characters: characters.isNotEmpty ? characters : null,
      corporations: corporations.isNotEmpty ? corporations : null,
      alliances: alliances.isNotEmpty ? alliances : null,
    );
  }

  void _checkForAlerts(dynamic kill) {
    // Basic logic for Intel Alerts: Check if the kill happened in a watched system.
    // Real implementation would cross-reference IntelAlerts table.
    // For MVP, we alert if a watched system has a kill over 100m ISK or just any kill.
    
    // Check if the system is watched
    final isWatchedSystem = _currentWatchList.any((w) => 
      w.watchType == 'system' && w.entityId == kill.solarSystemId
    );

    if (isWatchedSystem) {
      final value = kill.zkb.totalValue ?? 0.0;
      final valueStr = (value / 1000000).toStringAsFixed(1);
      
      Log.i('INTEL', 'ALERT TRIGGERED: Killmail in watched system ${kill.solarSystemId} for ${valueStr}M ISK');
      
      final notification = LocalNotification(
        identifier: 'intel_${kill.killmailId}',
        title: 'Intel Alert: Activity Detected',
        body: 'Killmail in watched system! Value: ${valueStr}M ISK',
      );
      
      notification.show();
    }
  }

  void dispose() {
    Log.d('INTEL', 'IntelAlertService.dispose() - START');
    _configSub?.cancel();
    _killmailSub?.cancel();
  }
}
