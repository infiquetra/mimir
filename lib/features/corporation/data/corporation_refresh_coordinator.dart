import 'package:drift/drift.dart';
import 'package:mimir/core/database/app_database.dart';

class LeaseClaim {
  const LeaseClaim({required this.won, this.jobToken});

  final bool won;
  final String? jobToken;
}

/// SQLite CAS single-flight, Retry-After, backoff 30/60/120/300/300.
class CorporationRefreshCoordinator {
  CorporationRefreshCoordinator({
    required this.database,
    this.processId = 'engine-a',
    this.tenant = 'tranquility',
    this.application = 'mimir',
  });

  final AppDatabase database;
  final String processId;
  final String tenant;
  final String application;

  static const backoffSchedule = [30, 60, 120, 300, 300];

  int backoffSeconds(int failureCount) {
    if (failureCount <= 0) return backoffSchedule.first;
    final index = failureCount - 1;
    if (index >= backoffSchedule.length) return backoffSchedule.last;
    return backoffSchedule[index];
  }

  Future<LeaseClaim> claim({
    required String resourceKey,
    required String jobToken,
    required DateTime now,
    Duration ttl = const Duration(seconds: 60),
  }) async {
    return database.transaction(() async {
      final existing = await (database.select(
        database.esiRequestLeases,
      )..where((row) => row.resourceKey.equals(resourceKey))).getSingleOrNull();
      final nowMs = now.millisecondsSinceEpoch;
      if (existing != null) {
        final until = existing.leaseUntilMs ?? 0;
        if (until > nowMs && existing.jobToken != jobToken) {
          return LeaseClaim(won: false, jobToken: existing.jobToken);
        }
      }
      await database
          .into(database.esiRequestLeases)
          .insertOnConflictUpdate(
            EsiRequestLeasesCompanion.insert(
              resourceKey: resourceKey,
              tenant: Value(tenant),
              application: Value(application),
              ownerProcess: Value(processId),
              jobToken: Value(jobToken),
              leaseUntilMs: Value(now.add(ttl).millisecondsSinceEpoch),
              heartbeatAtMs: Value(nowMs),
            ),
          );
      return LeaseClaim(won: true, jobToken: jobToken);
    });
  }

  DateTime? retryAfterDeadline({
    required DateTime now,
    int? retryAfterSeconds,
  }) {
    if (retryAfterSeconds == null) return null;
    return now.add(Duration(seconds: retryAfterSeconds));
  }

  Future<void> observeRateLimit({
    required int characterId,
    required String rateGroup,
    int? retryAfterSeconds,
    DateTime? now,
  }) async {
    final clock = (now ?? DateTime.now()).toUtc();
    final retryAt = retryAfterSeconds == null
        ? null
        : clock
              .add(Duration(seconds: retryAfterSeconds))
              .millisecondsSinceEpoch;
    await database
        .into(database.esiRateBuckets)
        .insertOnConflictUpdate(
          EsiRateBucketsCompanion.insert(
            tenant: tenant,
            application: application,
            characterId: characterId,
            rateGroup: rateGroup,
            retryAfterAtMs: Value(retryAt),
            observedAtMs: Value(clock.millisecondsSinceEpoch),
          ),
        );
  }
}
