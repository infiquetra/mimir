import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/logging/logger.dart';
import '../domain/killmail_models.dart';

class IntelRepository {
  final AppDatabase _db;

  IntelRepository(this._db);

  Future<void> cacheKillmail(ZKillmail killmail) async {
    try {
      await _db.into(_db.killmails).insert(
        KillmailsCompanion.insert(
          killmailId: drift.Value(killmail.killmailId),
          killmailTime: killmail.killmailTime,
          solarSystemId: killmail.solarSystemId,
          victimCharacterId: drift.Value(killmail.victim.characterId),
          victimCorporationId: drift.Value(killmail.victim.corporationId),
          victimAllianceId: drift.Value(killmail.victim.allianceId),
          victimShipTypeId: killmail.victim.shipTypeId,
          totalValue: killmail.totalValue,
          killmailJson: jsonEncode(killmail.toJson()),
          cachedAt: DateTime.now(),
        ),
      );
    } catch (e, st) {
      Log.e('INTEL', 'Failed to cache killmail ${killmail.killmailId}', e, st);
    }
  }

  Future<List<ZKillmail>> getRecentKills({
    List<int> systems = const [],
    List<int> regions = const [],
    required DateTime since,
  }) async {
    final query = _db.select(_db.killmails)
      ..where((t) => t.killmailTime.isBiggerOrEqualValue(since));

    if (systems.isNotEmpty) {
      query.where((t) => t.solarSystemId.isIn(systems));
    }

    query.orderBy([(t) => drift.OrderingTerm(expression: t.killmailTime, mode: drift.OrderingMode.desc)]);
    query.limit(100);

    final results = await query.get();

    return results.map((row) {
      final json = jsonDecode(row.killmailJson);
      return ZKillmail.fromJson(json);
    }).toList();
  }

  Stream<List<ZKillmail>> watchRecentKills({
    List<int> systems = const [],
    int limit = 100,
  }) {
    final query = _db.select(_db.killmails);

    if (systems.isNotEmpty) {
      query.where((t) => t.solarSystemId.isIn(systems));
    }

    query.orderBy([(t) => drift.OrderingTerm(expression: t.killmailTime, mode: drift.OrderingMode.desc)]);
    query.limit(limit);

    return query.watch().map((results) {
      return results.map((row) {
        final json = jsonDecode(row.killmailJson);
        return ZKillmail.fromJson(json);
      }).toList();
    });
  }

  Stream<List<WatchListData>> watchConfig() {
    return _db.select(_db.watchList).watch();
  }

  Future<void> addWatchEntity(int entityId, String type, String targetName) async {
    Log.i('INTEL', 'Adding watch entity: $entityId ($type, $targetName)');
    await _db.into(_db.watchList).insertOnConflictUpdate(
      WatchListCompanion(
        id: drift.Value('${type}_$entityId'),
        watchType: drift.Value(type),
        entityId: drift.Value(entityId),
        targetName: drift.Value(targetName),
        reason: const drift.Value('Manual tracking'),
        addedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> removeWatchEntity(int entityId, String watchType) async {
    await (_db.delete(_db.watchList)..where((t) => t.id.equals('${watchType}_$entityId'))).go();
  }

  Future<void> clearOldKillmails(Duration maxAge) async {
    final threshold = DateTime.now().subtract(maxAge);
    await (_db.delete(_db.killmails)..where((t) => t.cachedAt.isSmallerThanValue(threshold))).go();
  }
}
