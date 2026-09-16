// C1 RED contracts for AppDatabase schema 22.
// Compile against current schema 21 so these fail as assertions.
// Expected RED until GREEN implements design §2.1–§2.3:
// - schemaVersion stays 21; v21 files do not grow corporation tables.
// - injected failure is ignored; no transactional 21→22 upgrade.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/corporation/data/corporation_tables.dart';
import 'package:path/path.dart' as p;

import '../../../fixtures/corporation/corporation_fixtures.dart';
import 'corporation_schema_support.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    AppDatabase.debugFailCorporationMigration = false;
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    AppDatabase.debugFailCorporationMigration = false;
    await database.close();
  });

  group('P19 schema 22', () {
    test('schemaVersion is 22', () {
      expect(database.schemaVersion, 22);
    });

    test(
      'schema 21 to 22 creates corporation tables and keeps sentinel data',
      () async {
        final dir = await Directory.systemTemp.createTemp('c1-corp-mig-');
        final file = File(p.join(dir.path, 'app.sqlite'));
        addTearDown(() async {
          if (await dir.exists()) await dir.delete(recursive: true);
        });

        final seeded = AppDatabase.forTesting(NativeDatabase(file));
        await seedSentinelCharacter(seeded, characterId: kAdaId, name: 'Ada');
        await seedExplorationSignature(
          seeded,
          id: 'sig-ada',
          characterId: kAdaId,
        );
        await seedCombatEnrichment(seeded, id: 'enc-ada');
        await seeded.close();

        final reset = AppDatabase.forTesting(NativeDatabase(file));
        for (final name in CorporationTableNames.all) {
          await reset.customStatement('DROP TABLE IF EXISTS $name');
        }
        for (final name in CorporationTableNames.indices) {
          await reset.customStatement('DROP INDEX IF EXISTS $name');
        }
        await reset.customStatement('PRAGMA user_version = 21');
        await reset.close();

        final upgraded = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(upgraded.close);
        expect(upgraded.schemaVersion, 22);
        expect(await sqliteUserVersion(upgraded), 22);
        for (final name in CorporationTableNames.all) {
          expect(
            await corporationTableExists(upgraded, name),
            isTrue,
            reason: name,
          );
        }
        for (final name in CorporationTableNames.indices) {
          expect(
            await corporationIndexExists(upgraded, name),
            isTrue,
            reason: name,
          );
        }

        final characters = await upgraded.getAllCharacters();
        expect(characters, hasLength(1));
        expect(characters.single.characterId, kAdaId);
        expect(characters.single.name, 'Ada');
        expect(await upgraded.getLatestWalletBalance(kAdaId), 1234567.89);
        final signatures = await upgraded
            .customSelect(
              'SELECT id FROM tracked_signatures WHERE character_id = ?',
              variables: [Variable.withInt(kAdaId)],
            )
            .get();
        expect(signatures, hasLength(1));
        final enrichments = await upgraded
            .customSelect(
              'SELECT parsed_encounter_id FROM combat_encounter_enrichments',
            )
            .get();
        expect(enrichments, hasLength(1));
        final settings = await upgraded
            .customSelect('SELECT id FROM app_settings_table')
            .get();
        expect(settings, isNotEmpty);
      },
    );

    test(
      'injected migration failure rolls back to schema 21 without corp tables',
      () async {
        final dir = await Directory.systemTemp.createTemp('c1-corp-rollback-');
        final file = File(p.join(dir.path, 'app.sqlite'));
        addTearDown(() async {
          if (await dir.exists()) await dir.delete(recursive: true);
        });

        final seeded = AppDatabase.forTesting(NativeDatabase(file));
        await seedSentinelCharacter(seeded, characterId: kAdaId, name: 'Ada');
        await seeded.close();

        final reset = AppDatabase.forTesting(NativeDatabase(file));
        for (final name in CorporationTableNames.all) {
          await reset.customStatement('DROP TABLE IF EXISTS $name');
        }
        for (final name in CorporationTableNames.indices) {
          await reset.customStatement('DROP INDEX IF EXISTS $name');
        }
        await reset.customStatement('PRAGMA user_version = 21');
        await reset.close();

        AppDatabase.debugFailCorporationMigration = true;
        await expectLater(() async {
          final failing = AppDatabase.forTesting(NativeDatabase(file));
          await failing.customSelect('SELECT 1').get();
          await failing.close();
        }, throwsA(isA<Object>()));

        AppDatabase.debugFailCorporationMigration = false;
        final probe = NativeDatabase(file);
        addTearDown(probe.close);
        await probe.ensureOpen(_FrozenSchema21());
        final version = await probe.runSelect('PRAGMA user_version', []);
        expect(version.single['user_version'], 21);
        final assets = await probe.runSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'corporation_assets'",
          const [],
        );
        expect(assets, isEmpty);
        final ada = await probe.runSelect(
          'SELECT character_id FROM characters WHERE character_id = ?',
          [kAdaId],
        );
        expect(ada, isNotEmpty);
      },
    );
  });
}

class _FrozenSchema21 implements QueryExecutorUser {
  @override
  int get schemaVersion => 21;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
