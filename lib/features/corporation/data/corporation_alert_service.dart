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
      return false;
    }
    nativeDeliveries += 1;
    return true;
  }
}

class CorporationFuelMonitor {
  const CorporationFuelMonitor();

  bool shouldRun({required bool isMainWindow, required bool optedIn}) => true;
}

/// Naive C5 alerts: every engine inserts a delivery claim; denied permission
/// is silent with no in-app warning.
class CorporationAlertService {
  const CorporationAlertService();

  Future<bool> claimDelivery({
    required AppDatabase database,
    required String ownerKey,
    required String episodeUuid,
    required String engine,
  }) async {
    await database.customStatement(
      '''
      INSERT INTO corporation_fuel_alert_episodes (
        owner_key, episode_uuid, delivery_claim
      ) VALUES (?, ?, ?)
      ''',
      [ownerKey, '$episodeUuid-$engine', engine],
    );
    return true;
  }

  Future<void> notify({
    required CorporationNotificationAdapter adapter,
    required String episodeId,
  }) async {
    await adapter.deliver(episodeId: episodeId, body: 'Fuel');
  }
}
