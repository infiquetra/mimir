import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Characters table for storing EVE Online character data.
///
/// Each row represents an authenticated character with their
/// basic profile information and token expiry tracking.
class Characters extends Table {
  /// EVE character ID (primary key).
  IntColumn get characterId => integer()();

  /// Character name.
  TextColumn get name => text()();

  /// Corporation ID the character belongs to.
  IntColumn get corporationId => integer()();

  /// Corporation name (cached for display).
  TextColumn get corporationName => text()();

  /// Alliance ID (null if not in an alliance).
  IntColumn get allianceId => integer().nullable()();

  /// Alliance name (null if not in an alliance).
  TextColumn get allianceName => text().nullable()();

  /// URL to character portrait image.
  TextColumn get portraitUrl => text()();

  /// OAuth refresh token for this character.
  TextColumn get refreshToken => text().nullable()();

  /// Current OAuth access token (cached).
  TextColumn get accessToken => text().nullable()();

  /// When the OAuth token expires.
  DateTimeColumn get tokenExpiry => dateTime()();

  /// Last time character data was refreshed from ESI.
  DateTimeColumn get lastUpdated => dateTime()();

  /// Whether this is the currently active character.
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {characterId};
}

/// Cached skill queue entries for characters.
///
/// Stores the skill training queue for offline viewing
/// and notification scheduling.
class SkillQueueEntries extends Table {
  /// Auto-incrementing ID for this queue entry.
  IntColumn get id => integer().autoIncrement()();

  /// Character ID this queue entry belongs to.
  IntColumn get characterId =>
      integer().references(Characters, #characterId)();

  /// Position in the training queue (0 = currently training).
  IntColumn get queuePosition => integer()();

  /// Skill type ID from EVE SDE.
  IntColumn get skillId => integer()();

  /// Target level being trained (1-5).
  IntColumn get finishedLevel => integer()();

  /// When training started for this skill.
  DateTimeColumn get startDate => dateTime().nullable()();

  /// When training will complete.
  DateTimeColumn get finishDate => dateTime().nullable()();

  /// Training start skill points.
  IntColumn get trainingStartSp => integer().nullable()();

  /// Skill points at completion.
  IntColumn get levelEndSp => integer().nullable()();

  /// Skill points when this level started.
  IntColumn get levelStartSp => integer().nullable()();
}

/// Wallet transactions for characters.
///
/// Caches wallet journal entries for offline viewing.
class WalletJournalEntries extends Table {
  /// Transaction ID (primary key).
  IntColumn get id => integer()();

  /// Character ID this entry belongs to.
  IntColumn get characterId =>
      integer().references(Characters, #characterId)();

  /// ISK amount (positive = income, negative = expense).
  RealColumn get amount => real()();

  /// Running balance after this transaction.
  RealColumn get balance => real()();

  /// Transaction type (e.g., 'market_transaction', 'player_donation').
  TextColumn get refType => text()();

  /// First party ID (source or self).
  IntColumn get firstPartyId => integer().nullable()();

  /// Second party ID (destination or counterparty).
  IntColumn get secondPartyId => integer().nullable()();

  /// Transaction description/reason.
  TextColumn get description => text().nullable()();

  /// When the transaction occurred.
  DateTimeColumn get date => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Wallet balance snapshots for tracking over time.
class WalletBalances extends Table {
  /// Auto-incrementing ID.
  IntColumn get id => integer().autoIncrement()();

  /// Character ID.
  IntColumn get characterId =>
      integer().references(Characters, #characterId)();

  /// Balance in ISK.
  RealColumn get balance => real()();

  /// When this balance was recorded.
  DateTimeColumn get recordedAt => dateTime()();
}

/// Application database using Drift.
///
/// Handles all local persistence for Mimir including:
/// - Character profiles and authentication state
/// - Skill queue caching
/// - Wallet transaction history
@DriftDatabase(tables: [
  Characters,
  SkillQueueEntries,
  WalletJournalEntries,
  WalletBalances,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with custom executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration from version 1 to 2: Add token storage columns.
        if (from < 2) {
          await m.addColumn(characters, characters.refreshToken);
          await m.addColumn(characters, characters.accessToken);
        }
      },
    );
  }

  // Character operations

  /// Get all stored characters.
  Future<List<Character>> getAllCharacters() => select(characters).get();

  /// Watch all characters for reactive updates.
  Stream<List<Character>> watchAllCharacters() => select(characters).watch();

  /// Get the currently active character.
  Future<Character?> getActiveCharacter() {
    return (select(characters)..where((c) => c.isActive.equals(true)))
        .getSingleOrNull();
  }

  /// Watch the active character for reactive updates.
  Stream<Character?> watchActiveCharacter() {
    return (select(characters)..where((c) => c.isActive.equals(true)))
        .watchSingleOrNull();
  }

  /// Insert or update a character.
  Future<void> upsertCharacter(CharactersCompanion character) {
    return into(characters).insertOnConflictUpdate(character);
  }

  /// Set a character as the active one (deactivates others).
  Future<void> setActiveCharacter(int characterId) async {
    await transaction(() async {
      // Deactivate all characters.
      await (update(characters)
            ..where((c) => c.isActive.equals(true)))
          .write(const CharactersCompanion(isActive: Value(false)));

      // Activate the selected character.
      await (update(characters)
            ..where((c) => c.characterId.equals(characterId)))
          .write(const CharactersCompanion(isActive: Value(true)));
    });
  }

  /// Delete a character and all related data.
  Future<void> deleteCharacter(int characterId) async {
    await transaction(() async {
      await (delete(skillQueueEntries)
            ..where((e) => e.characterId.equals(characterId)))
          .go();
      await (delete(walletJournalEntries)
            ..where((e) => e.characterId.equals(characterId)))
          .go();
      await (delete(walletBalances)
            ..where((e) => e.characterId.equals(characterId)))
          .go();
      await (delete(characters)
            ..where((c) => c.characterId.equals(characterId)))
          .go();
    });
  }

  // Skill queue operations

  /// Replace skill queue for a character.
  Future<void> replaceSkillQueue(
    int characterId,
    List<SkillQueueEntriesCompanion> entries,
  ) async {
    await transaction(() async {
      await (delete(skillQueueEntries)
            ..where((e) => e.characterId.equals(characterId)))
          .go();
      await batch((b) {
        b.insertAll(skillQueueEntries, entries);
      });
    });
  }

  /// Get skill queue for a character.
  Future<List<SkillQueueEntry>> getSkillQueue(int characterId) {
    return (select(skillQueueEntries)
          ..where((e) => e.characterId.equals(characterId))
          ..orderBy([(e) => OrderingTerm.asc(e.queuePosition)]))
        .get();
  }

  /// Watch skill queue for reactive updates.
  Stream<List<SkillQueueEntry>> watchSkillQueue(int characterId) {
    return (select(skillQueueEntries)
          ..where((e) => e.characterId.equals(characterId))
          ..orderBy([(e) => OrderingTerm.asc(e.queuePosition)]))
        .watch();
  }

  // Wallet operations

  /// Insert wallet journal entries (ignores duplicates).
  Future<void> insertWalletJournalEntries(
    List<WalletJournalEntriesCompanion> entries,
  ) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(walletJournalEntries, entries);
    });
  }

  /// Get wallet journal for a character.
  Future<List<WalletJournalEntry>> getWalletJournal(
    int characterId, {
    int limit = 50,
  }) {
    return (select(walletJournalEntries)
          ..where((e) => e.characterId.equals(characterId))
          ..orderBy([(e) => OrderingTerm.desc(e.date)])
          ..limit(limit))
        .get();
  }

  /// Watch wallet journal for reactive updates.
  Stream<List<WalletJournalEntry>> watchWalletJournal(
    int characterId, {
    int limit = 50,
  }) {
    return (select(walletJournalEntries)
          ..where((e) => e.characterId.equals(characterId))
          ..orderBy([(e) => OrderingTerm.desc(e.date)])
          ..limit(limit))
        .watch();
  }

  /// Record a wallet balance snapshot.
  Future<void> recordWalletBalance(int characterId, double balance) {
    return into(walletBalances).insert(
      WalletBalancesCompanion.insert(
        characterId: characterId,
        balance: balance,
        recordedAt: DateTime.now(),
      ),
    );
  }

  /// Get latest wallet balance for a character.
  Future<double?> getLatestWalletBalance(int characterId) async {
    final result = await (select(walletBalances)
          ..where((e) => e.characterId.equals(characterId))
          ..orderBy([(e) => OrderingTerm.desc(e.recordedAt)])
          ..limit(1))
        .getSingleOrNull();
    return result?.balance;
  }
}

/// Global database path, set during main window initialization.
/// Sub-windows should set this before creating AppDatabase.
String? _globalDbPath;

/// Whether this is a sub-window (set by main.dart).
/// Sub-windows don't have access to native plugins like path_provider.
bool _isSubWindow = false;

/// Returns true if running in a sub-window context.
///
/// Sub-windows can't use native plugins (path_provider, etc.) because
/// they run in separate Flutter engines without registered plugin channels.
/// Use this to conditionally disable features that require native plugins.
bool get isSubWindow => _isSubWindow;

/// Sets the global database path for sub-windows.
///
/// Also marks this as a sub-window context, disabling native plugin usage.
void setDatabasePath(String path) {
  _globalDbPath = path;
  _isSubWindow = true; // Path is only set for sub-windows
  debugPrint('Database path set: $path');
}

/// Gets the database path (resolves it if not already set).
Future<String> getDatabasePath() async {
  if (_globalDbPath != null) return _globalDbPath!;

  final dbFolder = await getApplicationDocumentsDirectory();
  _globalDbPath = p.join(dbFolder.path, 'mimir.db');
  return _globalDbPath!;
}

/// Opens the database connection.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    try {
      final path = await getDatabasePath();
      final file = File(path);
      debugPrint('Database: Opening at $path');
      final db = NativeDatabase.createInBackground(file);
      debugPrint('Database: Connection established successfully');
      return db;
    } catch (e, stack) {
      debugPrint('Database: ERROR opening connection: $e');
      debugPrint('Database: Stack trace: $stack');
      rethrow;
    }
  });
}
