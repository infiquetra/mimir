// C2 RED: SQLite CAS single-flight, Retry-After, backoff 30/60/120/300/300.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/corporation/data/corporation_refresh_coordinator.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('second engine cannot claim a live resource key', () async {
    final first = CorporationRefreshCoordinator(
      database: database,
      processId: 'engine-a',
    );
    final second = CorporationRefreshCoordinator(
      database: database,
      processId: 'engine-b',
    );
    final a = await first.claim(
      resourceKey: 'helios/assets',
      jobToken: 'job-a',
      now: kCorporationT0,
    );
    final b = await second.claim(
      resourceKey: 'helios/assets',
      jobToken: 'job-b',
      now: kCorporationT0,
    );
    expect(a.won, isTrue);
    expect(b.won, isFalse);
    final row = await database
        .customSelect(
          'SELECT job_token, owner_process FROM esi_request_leases WHERE resource_key = ?',
          variables: [Variable.withString('helios/assets')],
        )
        .getSingle();
    expect(row.read<String>('job_token'), 'job-a');
    expect(row.read<String>('owner_process'), 'engine-a');
  });

  test('backoff schedule is 30/60/120/300/300', () {
    expect(CorporationRefreshCoordinator.backoffSchedule, [
      30,
      60,
      120,
      300,
      300,
    ]);
    expect(
      CorporationRefreshCoordinator(database: database).backoffSeconds(1),
      30,
    );
    expect(
      CorporationRefreshCoordinator(database: database).backoffSeconds(5),
      300,
    );
  });

  test('Retry-After 120s suppresses 12:01 and allows 12:02', () {
    final coordinator = CorporationRefreshCoordinator(database: database);
    final deadline = coordinator.retryAfterDeadline(
      now: kCorporationT0,
      retryAfterSeconds: 120,
    );
    expect(deadline, kCorporationT0.add(const Duration(seconds: 120)));
    expect(
      kCorporationT0.add(const Duration(minutes: 1)).isBefore(deadline!),
      isTrue,
    );
    expect(
      kCorporationT0.add(const Duration(minutes: 2)).isBefore(deadline),
      isFalse,
    );
  });

  test('429 records retry-after on the character rate bucket', () async {
    final coordinator = CorporationRefreshCoordinator(database: database);
    await coordinator.observeRateLimit(
      characterId: kCyraId,
      rateGroup: 'corp-asset',
      retryAfterSeconds: 120,
      now: kCorporationT0,
    );
    final row = await database
        .customSelect(
          '''
          SELECT retry_after_at_ms FROM esi_rate_buckets
          WHERE character_id = ? AND rate_group = ?
          ''',
          variables: [
            Variable.withInt(kCyraId),
            Variable.withString('corp-asset'),
          ],
        )
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(
      row!.read<int>('retry_after_at_ms'),
      kCorporationT0.add(const Duration(seconds: 120)).millisecondsSinceEpoch,
    );
  });
}
