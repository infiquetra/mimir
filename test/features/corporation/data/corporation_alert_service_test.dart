// C5 RED: unique SQLite delivery claim, permission fallback, main-engine opt-in.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/corporation/data/corporation_alert_service.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('two engines produce a single native delivery claim', () async {
    const service = CorporationAlertService();
    final first = await service.claimDelivery(
      database: database,
      ownerKey: 'cyra/8001',
      episodeUuid: 'ep-1',
      engine: 'engine-a',
    );
    final second = await service.claimDelivery(
      database: database,
      ownerKey: 'cyra/8001',
      episodeUuid: 'ep-1',
      engine: 'engine-b',
    );
    expect(first, isTrue);
    expect(second, isFalse);
    final rows = await database
        .customSelect(
          '''
          SELECT episode_uuid, delivery_claim
          FROM corporation_fuel_alert_episodes
          WHERE owner_key = ?
          ''',
          variables: [Variable.withString('cyra/8001')],
        )
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.read<String>('episode_uuid'), 'ep-1');
  });

  test(
    'permission denial keeps in-app warnings and skips native delivery',
    () async {
      const service = CorporationAlertService();
      final adapter = CorporationNotificationAdapter(permissionDenied: true);
      await service.notify(adapter: adapter, episodeId: 'ep-1');
      expect(adapter.nativeDeliveries, 0);
      expect(adapter.inAppWarnings, isNotEmpty);
    },
  );

  test('monitor runs only on the main window for an opted-in character', () {
    const monitor = CorporationFuelMonitor();
    expect(monitor.shouldRun(isMainWindow: true, optedIn: true), isTrue);
    expect(monitor.shouldRun(isMainWindow: false, optedIn: true), isFalse);
    expect(monitor.shouldRun(isMainWindow: true, optedIn: false), isFalse);
  });
}
