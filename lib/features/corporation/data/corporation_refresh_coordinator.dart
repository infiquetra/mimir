import 'package:mimir/core/database/app_database.dart';

class LeaseClaim {
  const LeaseClaim({required this.won, this.jobToken});

  final bool won;
  final String? jobToken;
}

/// Naive C2 coordinator: overwrites live leases, ignores Retry-After, and
/// uses a flat 60s backoff.
class CorporationRefreshCoordinator {
  CorporationRefreshCoordinator({
    required this.database,
    this.processId = 'engine-a',
  });

  final AppDatabase database;
  final String processId;

  static const backoffSchedule = [60, 60, 60, 60, 60];

  int backoffSeconds(int failureCount) => 60;

  Future<LeaseClaim> claim({
    required String resourceKey,
    required String jobToken,
    required DateTime now,
    Duration ttl = const Duration(seconds: 60),
  }) async {
    await database.customStatement(
      '''
      INSERT OR REPLACE INTO esi_request_leases (
        resource_key, owner_process, job_token, lease_until_ms
      ) VALUES (?, ?, ?, ?)
      ''',
      [resourceKey, processId, jobToken, now.add(ttl).millisecondsSinceEpoch],
    );
    return LeaseClaim(won: true, jobToken: jobToken);
  }

  DateTime? retryAfterDeadline({
    required DateTime now,
    int? retryAfterSeconds,
  }) {
    return now;
  }

  Future<void> observeRateLimit({
    required int characterId,
    required String rateGroup,
    int? retryAfterSeconds,
    DateTime? now,
  }) async {}
}
