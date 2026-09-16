import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:mimir/core/database/app_database.dart';
import '../../../fixtures/corporation/corporation_fixtures.dart';

Future<bool> corporationTableExists(AppDatabase db, String name) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable.withString(name)],
      )
      .get();
  return rows.isNotEmpty;
}

Future<bool> corporationIndexExists(AppDatabase db, String name) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
        variables: [Variable.withString(name)],
      )
      .get();
  return rows.isNotEmpty;
}

Future<int> sqliteUserVersion(AppDatabase db) async {
  final row = await db.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

Future<Map<String, String>> columnTypes(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return {
    for (final row in rows) row.read<String>('name'): row.read<String>('type'),
  };
}

Future<void> seedSentinelCharacter(
  AppDatabase db, {
  required int characterId,
  required String name,
}) async {
  await db.upsertCharacter(
    CharactersCompanion.insert(
      characterId: Value(characterId),
      name: name,
      corporationId: kHeliosId,
      corporationName: 'Helios Research',
      portraitUrl: 'https://example.com/$characterId',
      tokenExpiry: kCorporationT0.add(const Duration(hours: 1)),
      lastUpdated: kCorporationT0,
    ),
  );
  await db.recordWalletBalance(characterId, 1234567.89);
}

Future<void> seedExplorationSignature(
  AppDatabase db, {
  required String id,
  required int characterId,
}) {
  return db.customStatement(
    '''
    INSERT INTO tracked_signatures (
      id, character_id, system_id, code, scan_group, type,
      lifecycle, first_seen_at_ms, last_seen_at_ms, row_revision
    ) VALUES (?, ?, 9101, 'AAA-111', 'Cosmic Signature', 'unknown', 'active', ?, ?, 1)
    ''',
    [
      id,
      characterId,
      kCorporationT0.millisecondsSinceEpoch,
      kCorporationT0.millisecondsSinceEpoch,
    ],
  );
}

Future<void> seedCombatEnrichment(AppDatabase db, {required String id}) {
  return db.customStatement(
    '''
    INSERT INTO combat_encounter_enrichments (
      parsed_encounter_id, status, source, match_confidence, match_reason,
      normalized_evidence_json, created_at_ms, updated_at_ms
    ) VALUES (?, 'ready', 'test', 1.0, 'fixture', '{}', ?, ?)
    ''',
    [
      id,
      kCorporationT0.millisecondsSinceEpoch,
      kCorporationT0.millisecondsSinceEpoch,
    ],
  );
}

/// Naive C1 schema: REAL money, nullable amounts default 0, no unique grants,
/// no millisecond-preserving contract, missing indices.
Future<void> createNaiveCorporationSchema(AppDatabase db) async {
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS character_authorization_states (
      tenant TEXT NOT NULL,
      character_id INTEGER NOT NULL,
      incarnation TEXT,
      grant_epoch INTEGER,
      PRIMARY KEY (tenant, character_id)
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS corporation_context_states (
      tenant TEXT NOT NULL PRIMARY KEY,
      selected_character_id INTEGER,
      context_generation INTEGER DEFAULT 0,
      selection_revision INTEGER DEFAULT 0
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS corporation_wallet_balances (
      snapshot_id TEXT NOT NULL,
      division INTEGER NOT NULL,
      owner_character_id INTEGER NOT NULL,
      balance REAL NOT NULL DEFAULT 0,
      PRIMARY KEY (snapshot_id, division)
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS corporation_wallet_journal (
      owner_key TEXT NOT NULL,
      journal_key TEXT NOT NULL,
      owner_character_id INTEGER NOT NULL,
      amount REAL NOT NULL DEFAULT 0,
      occurred_at_ms INTEGER,
      PRIMARY KEY (owner_key, journal_key)
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS corporation_profiles (
      tenant TEXT NOT NULL,
      corporation_id INTEGER NOT NULL,
      name TEXT,
      PRIMARY KEY (tenant, corporation_id)
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS exact_market_prices (
      tenant TEXT NOT NULL,
      type_id INTEGER NOT NULL,
      average_price REAL,
      PRIMARY KEY (tenant, type_id)
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS corporation_capabilities (
      owner_key TEXT NOT NULL PRIMARY KEY,
      owner_character_id INTEGER NOT NULL,
      capability TEXT,
      endpoint_until_ms INTEGER
    )
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS corporation_members (
      snapshot_id TEXT,
      member_id INTEGER
    )
  ''');
}
