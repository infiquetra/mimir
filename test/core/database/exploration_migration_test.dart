// X2 RED contracts for AppDatabase schema 21 and owned notebook storage.
// Compile against current schema 20 so these fail as assertions, not
// missing imports.
//
// Expected RED until GREEN implements design §2.3:
// - P02: schemaVersion stays 20; v20 files do not grow exploration tables.
// - P11: no partial unique active (character, system, code) index.
// - P12: Drift DateTime columns drop milliseconds.
// - P16: deleteCharacter leaves private notebook rows.
// - On-disk reopen cannot round-trip millisecond UTC instants.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:path/path.dart' as p;

import '../../features/exploration/fixtures/exploration_fixtures.dart';

const _explorationTables = [
  'eve_scout_feed_states',
  'eve_scout_signatures',
  'tracked_signatures',
  'tracked_connections',
  'exploration_notebook_scopes',
  'exploration_import_operations',
  'exploration_notebook_preferences',
  'exploration_window_preferences',
  'exploration_location_observations',
];

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<bool> tableExists(AppDatabase db, String name) async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [Variable.withString(name)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<bool> indexExists(AppDatabase db, String name) async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
          variables: [Variable.withString(name)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<void> seedPilot(
    AppDatabase db, {
    required int characterId,
    required String name,
  }) async {
    await db.upsertCharacter(
      CharactersCompanion.insert(
        characterId: Value(characterId),
        name: name,
        corporationId: 98000001,
        corporationName: 'Fixture Corp',
        portraitUrl: 'https://example.com/$characterId',
        tokenExpiry: kExplorationT0.add(const Duration(hours: 1)),
        lastUpdated: kExplorationT0,
      ),
    );
    await db.replaceCharacterSkills(characterId, [
      CharacterSkillsCompanion.insert(
        characterId: characterId,
        skillId: 3300,
        trainedSkillLevel: 5,
        activeSkillLevel: 5,
        skillpointsInSkill: 256000,
        lastUpdated: kExplorationT0,
      ),
    ]);
    await db.recordWalletBalance(characterId, 1234567.89);
  }

  int lastSeenMs() => kExplorationT0
      .add(const Duration(milliseconds: 123))
      .millisecondsSinceEpoch;

  Future<void> insertActiveSignature(
    AppDatabase db, {
    required String id,
    required int characterId,
    required int systemId,
    required String code,
    required int lastSeenAtMs,
  }) {
    return db.customStatement(
      '''
      INSERT INTO tracked_signatures (
        id, character_id, system_id, code, scan_group, type,
        lifecycle, first_seen_at_ms, last_seen_at_ms, row_revision
      ) VALUES (?, ?, ?, ?, 'Cosmic Signature', 'unknown', 'active', ?, ?, 1)
      ''',
      [id, characterId, systemId, code, lastSeenAtMs, lastSeenAtMs],
    );
  }

  Future<void> insertConnection(
    AppDatabase db, {
    required String id,
    required String episodeId,
    required int characterId,
  }) {
    return db.customStatement(
      '''
      INSERT INTO tracked_connections (
        id, owner_signature_id, character_id, from_system_id, to_system_id,
        lifecycle, verified_at_ms, row_revision
      ) VALUES (?, ?, ?, ?, ?, 'active', ?, 1)
      ''',
      [id, episodeId, characterId, kAlphaSystemId, 9102, lastSeenMs()],
    );
  }

  Future<void> insertPublicSignature(AppDatabase db, {required String key}) {
    return db.customStatement(
      '''
      INSERT INTO eve_scout_signatures (
        scope_key, provider_record_key, hub_system_id, far_system_id,
        listed_snapshot_revision
      ) VALUES ('evescout:v2:all', ?, ?, ?, 1)
      ''',
      [key, kTurnurSystemId, kAlphaSystemId],
    );
  }

  Matcher isConstraintFailure() {
    return predicate((Object? error) {
      final text = error.toString().toLowerCase();
      return text.contains('unique') ||
          text.contains('constraint') ||
          text.contains('2067');
    }, 'a unique constraint failure');
  }

  group('P02 schema 21', () {
    test('schemaVersion is 21', () {
      expect(database.schemaVersion, 21);
    });

    test(
      'schema 20 to 21 creates exploration tables and keeps character data',
      () async {
        final dir = await Directory.systemTemp.createTemp('x2-expl-mig-');
        final file = File(p.join(dir.path, 'app.sqlite'));
        addTearDown(() async {
          if (await dir.exists()) await dir.delete(recursive: true);
        });

        final seeded = AppDatabase.forTesting(NativeDatabase(file));
        await seedPilot(seeded, characterId: kCharacter7, name: 'Pilot Seven');
        await seeded.close();

        final reset = AppDatabase.forTesting(NativeDatabase(file));
        for (final name in _explorationTables) {
          await reset.customStatement('DROP TABLE IF EXISTS $name');
        }
        await reset.customStatement(
          'DROP INDEX IF EXISTS tracked_signatures_active_scope_code',
        );
        await reset.customStatement('PRAGMA user_version = 20');
        await reset.close();

        final upgraded = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(upgraded.close);
        expect(upgraded.schemaVersion, 21);
        for (final name in _explorationTables) {
          expect(await tableExists(upgraded, name), isTrue, reason: name);
        }
        expect(
          await indexExists(upgraded, 'tracked_signatures_active_scope_code'),
          isTrue,
        );

        final characters = await upgraded.getAllCharacters();
        expect(characters, hasLength(1));
        expect(characters.single.characterId, kCharacter7);
        expect(characters.single.name, 'Pilot Seven');
        final skills = await upgraded.getCharacterSkills(kCharacter7);
        expect(skills, hasLength(1));
        expect(skills.single.skillId, 3300);
        expect(await upgraded.getLatestWalletBalance(kCharacter7), 1234567.89);
      },
    );
  });

  group('P11 unique active signature code', () {
    test(
      'duplicate active (character, system, code) is rejected; trash allows reuse',
      () async {
        expect(await tableExists(database, 'tracked_signatures'), isTrue);
        await seedPilot(
          database,
          characterId: kCharacter7,
          name: 'Pilot Seven',
        );
        final seen = lastSeenMs();
        await insertActiveSignature(
          database,
          id: 'sig-abc-1',
          characterId: kCharacter7,
          systemId: kAlphaSystemId,
          code: 'ABC-123',
          lastSeenAtMs: seen,
        );
        await expectLater(
          insertActiveSignature(
            database,
            id: 'sig-abc-2',
            characterId: kCharacter7,
            systemId: kAlphaSystemId,
            code: 'ABC-123',
            lastSeenAtMs: seen,
          ),
          throwsA(isConstraintFailure()),
        );

        await database.customStatement(
          "UPDATE tracked_signatures SET lifecycle = 'trash' WHERE id = ?",
          ['sig-abc-1'],
        );
        await insertActiveSignature(
          database,
          id: 'sig-abc-3',
          characterId: kCharacter7,
          systemId: kAlphaSystemId,
          code: 'ABC-123',
          lastSeenAtMs: seen,
        );
        final rows = await database
            .customSelect(
              "SELECT id, lifecycle FROM tracked_signatures WHERE code = 'ABC-123' ORDER BY id",
            )
            .get();
        expect(rows, hasLength(2));
        expect(
          rows.map((row) => row.read<String>('lifecycle')),
          containsAll(['trash', 'active']),
        );
      },
    );
  });

  group('P12 millisecond UTC timestamps', () {
    test('last_seen_at_ms round-trips exact UTC milliseconds', () async {
      expect(await tableExists(database, 'tracked_signatures'), isTrue);
      await seedPilot(database, characterId: kCharacter7, name: 'Pilot Seven');
      final instant = kExplorationT0.add(const Duration(milliseconds: 123));
      await insertActiveSignature(
        database,
        id: 'sig-ms',
        characterId: kCharacter7,
        systemId: kAlphaSystemId,
        code: 'MSE-001',
        lastSeenAtMs: instant.millisecondsSinceEpoch,
      );
      final row = await database
          .customSelect(
            'SELECT last_seen_at_ms FROM tracked_signatures WHERE id = ?',
            variables: [Variable.withString('sig-ms')],
          )
          .getSingle();
      final storedMs = row.read<int>('last_seen_at_ms');
      expect(storedMs, instant.millisecondsSinceEpoch);
      final restored = DateTime.fromMillisecondsSinceEpoch(
        storedMs,
        isUtc: true,
      );
      expect(restored.isUtc, isTrue);
      expect(restored.millisecond, 123);
      expect(restored, instant);
    });
  });

  group('P16 character deletion cleanup', () {
    test(
      'deleteCharacter removes private notebook rows and keeps public feed',
      () async {
        expect(await tableExists(database, 'tracked_signatures'), isTrue);
        expect(await tableExists(database, 'tracked_connections'), isTrue);
        expect(await tableExists(database, 'eve_scout_signatures'), isTrue);
        await seedPilot(
          database,
          characterId: kCharacter7,
          name: 'Pilot Seven',
        );
        await seedPilot(
          database,
          characterId: kCharacter8,
          name: 'Pilot Eight',
        );
        final seen = lastSeenMs();
        await insertActiveSignature(
          database,
          id: 'sig-7',
          characterId: kCharacter7,
          systemId: kAlphaSystemId,
          code: 'AAA-111',
          lastSeenAtMs: seen,
        );
        await insertConnection(
          database,
          id: 'conn-7',
          episodeId: 'sig-7',
          characterId: kCharacter7,
        );
        await insertActiveSignature(
          database,
          id: 'sig-8',
          characterId: kCharacter8,
          systemId: kAlphaSystemId,
          code: 'BBB-222',
          lastSeenAtMs: seen,
        );
        await insertPublicSignature(database, key: 'evescout:42');

        await database.deleteCharacter(kCharacter7);

        final privateSeven = await database
            .customSelect(
              'SELECT id FROM tracked_signatures WHERE character_id = ?',
              variables: [Variable.withInt(kCharacter7)],
            )
            .get();
        final connections = await database
            .customSelect(
              'SELECT id FROM tracked_connections WHERE character_id = ?',
              variables: [Variable.withInt(kCharacter7)],
            )
            .get();
        final privateEight = await database
            .customSelect(
              'SELECT id FROM tracked_signatures WHERE character_id = ?',
              variables: [Variable.withInt(kCharacter8)],
            )
            .get();
        final publicRows = await database
            .customSelect(
              'SELECT provider_record_key FROM eve_scout_signatures',
            )
            .get();
        expect(privateSeven, isEmpty);
        expect(connections, isEmpty);
        expect(privateEight, hasLength(1));
        expect(publicRows, hasLength(1));
        expect(await database.getCharacter(kCharacter7), isNull);
        expect(await database.getCharacter(kCharacter8), isNotNull);
      },
    );
  });

  group('on-disk reopen', () {
    test(
      'temp-file close and reopen preserves ms timestamps and rows',
      () async {
        final dir = await Directory.systemTemp.createTemp('x2-expl-reopen-');
        final file = File(p.join(dir.path, 'app.sqlite'));
        addTearDown(() async {
          if (await dir.exists()) await dir.delete(recursive: true);
        });

        final first = AppDatabase.forTesting(NativeDatabase(file));
        await seedPilot(first, characterId: kCharacter7, name: 'Pilot Seven');
        expect(await tableExists(first, 'tracked_signatures'), isTrue);
        final instant = kExplorationT0.add(const Duration(milliseconds: 123));
        await insertActiveSignature(
          first,
          id: 'sig-disk',
          characterId: kCharacter7,
          systemId: kAlphaSystemId,
          code: 'DSK-001',
          lastSeenAtMs: instant.millisecondsSinceEpoch,
        );
        await first.close();

        final second = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(second.close);
        expect(second.schemaVersion, 21);
        final characters = await second.getAllCharacters();
        expect(characters.single.name, 'Pilot Seven');
        final row = await second
            .customSelect(
              'SELECT last_seen_at_ms FROM tracked_signatures WHERE id = ?',
              variables: [Variable.withString('sig-disk')],
            )
            .getSingle();
        expect(
          row.read<int>('last_seen_at_ms'),
          instant.millisecondsSinceEpoch,
        );
      },
    );
  });
}
