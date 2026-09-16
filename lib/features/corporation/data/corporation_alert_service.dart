import 'package:drift/drift.dart';
import 'package:mimir/core/database/app_database.dart';

class CorporationNotificationAdapter {
  CorporationNotificationAdapter({this.permissionDenied = false});

  final bool permissionDenied;
  var nativeDeliveries = 0;
  final inAppWarnings = <String>[];

  Future<bool> deliver({
    required String episodeId,
    required String body,
  }) async {
    if (permissionDenied) {
      inAppWarnings.add('Notification permission denied');
      return false;
    }
    nativeDeliveries += 1;
    return true;
  }
}

class CorporationFuelMonitor {
  const CorporationFuelMonitor();

  bool shouldRun({required bool isMainWindow, required bool optedIn}) {
    return isMainWindow && optedIn;
  }
}

class CorporationAlertService {
  const CorporationAlertService();

  /// Unique (owner, episode) claim. The second engine loses the insert.
  Future<bool> claimDelivery({
    required AppDatabase database,
    required String ownerKey,
    required String episodeUuid,
    required String engine,
  }) async {
    await database
        .into(database.corporationFuelAlertEpisodes)
        .insert(
          CorporationFuelAlertEpisodesCompanion.insert(
            ownerKey: ownerKey,
            episodeUuid: episodeUuid,
            deliveryClaim: Value(engine),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final row =
        await (database.select(database.corporationFuelAlertEpisodes)..where(
              (tbl) =>
                  tbl.ownerKey.equals(ownerKey) &
                  tbl.episodeUuid.equals(episodeUuid),
            ))
            .getSingle();
    return row.deliveryClaim == engine;
  }

  Future<void> notify({
    required CorporationNotificationAdapter adapter,
    required String episodeId,
  }) async {
    final delivered = await adapter.deliver(episodeId: episodeId, body: 'Fuel');
    if (!delivered && adapter.inAppWarnings.isEmpty) {
      adapter.inAppWarnings.add('Native notifications unavailable');
    }
  }
}
