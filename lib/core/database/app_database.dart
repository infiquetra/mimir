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

  /// Faction ID (null if not in a faction warfare corp).
  IntColumn get factionId => integer().nullable()();

  /// Character security status (-10 to +10).
  RealColumn get securityStatus => real().withDefault(const Constant(0.0))();

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

/// Wallet market transactions (buy/sell on the market).
///
/// Stores market transaction history for tracking market activity.
/// Separate from journal entries as they contain market-specific details.
class WalletTransactions extends Table {
  /// Transaction ID (primary key).
  IntColumn get transactionId => integer()();

  /// Character ID this transaction belongs to.
  IntColumn get characterId =>
      integer().references(Characters, #characterId)();

  /// Item type ID from EVE SDE.
  IntColumn get typeId => integer()();

  /// Location ID (station or structure).
  IntColumn get locationId => integer()();

  /// Price per unit in ISK.
  RealColumn get unitPrice => real()();

  /// Quantity of items.
  IntColumn get quantity => integer()();

  /// Whether this is a buy (true) or sell (false) transaction.
  BoolColumn get isBuy => boolean()();

  /// Client ID (counterparty character/corporation).
  IntColumn get clientId => integer()();

  /// When the transaction occurred.
  DateTimeColumn get date => dateTime()();

  /// Reference to journal entry ID (if applicable).
  IntColumn get journalRefId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {transactionId};
}

/// Loyalty points per corporation.
///
/// Tracks LP holdings across different corporations for the character.
class LoyaltyPoints extends Table {
  /// Auto-incrementing ID.
  IntColumn get id => integer().autoIncrement()();

  /// Character ID.
  IntColumn get characterId =>
      integer().references(Characters, #characterId)();

  /// Corporation ID offering these loyalty points.
  IntColumn get corporationId => integer()();

  /// Amount of loyalty points.
  IntColumn get loyaltyPoints => integer()();

  /// When this data was last updated.
  DateTimeColumn get lastUpdated => dateTime()();
}

/// Asset cache for character assets (primarily for PLEX count).
///
/// Caches selected assets from the character's inventory.
/// Used to track PLEX (type_id 44992) without loading full asset list.
class AssetCache extends Table {
  /// Item ID (unique asset instance, primary key).
  IntColumn get itemId => integer()();

  /// Character ID this asset belongs to.
  IntColumn get characterId =>
      integer().references(Characters, #characterId)();

  /// Item type ID from EVE SDE.
  IntColumn get typeId => integer()();

  /// Quantity of this item.
  IntColumn get quantity => integer()();

  /// Location ID where the asset is stored.
  IntColumn get locationId => integer()();

  /// When this cache was last updated.
  DateTimeColumn get lastUpdated => dateTime()();

  @override
  Set<Column> get primaryKey => {itemId};
}

/// App-wide settings table (singleton pattern).
///
/// Stores application preferences and state. Only one row exists (id = 1).
class AppSettingsTable extends Table {
  /// Primary key (always 1 for singleton).
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// Startup behavior ('dashboard' or 'tray_only').
  TextColumn get startupBehavior =>
      text().withDefault(const Constant('dashboard'))();

  /// Whether the user has completed onboarding.
  BoolColumn get onboardingComplete =>
      boolean().withDefault(const Constant(false))();

  /// ESI Error limit remaining
  IntColumn get esiErrorLimitRemain =>
      integer().withDefault(const Constant(100))();

  /// ESI Error limit reset timestamp
  DateTimeColumn get esiErrorLimitReset => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Combat statistics from zkillboard.
///
/// Caches combat stats for characters to avoid excessive zkillboard API calls.
/// Data is refreshed periodically (minimum 1 hour between fetches).
class CombatStats extends Table {
  /// Character ID (primary key).
  IntColumn get characterId =>
      integer().references(Characters, #characterId)();

  /// Total kills (ships destroyed).
  IntColumn get kills => integer().withDefault(const Constant(0))();

  /// Total deaths (ships lost).
  IntColumn get deaths => integer().withDefault(const Constant(0))();

  /// ISK destroyed (from killing other ships).
  RealColumn get iskDestroyed => real().withDefault(const Constant(0.0))();

  /// ISK lost (from own ships destroyed).
  RealColumn get iskLost => real().withDefault(const Constant(0.0))();

  /// When this data was last fetched from zkillboard.
  DateTimeColumn get lastUpdated => dateTime()();

  @override
  Set<Column> get primaryKey => {characterId};
}

/// Character location and status information from ESI.
///
/// Caches current location, ship, and online status for fleet monitoring.
/// Data is refreshed periodically (minimum 5 minutes between fetches).
class CharacterStatuses extends Table {
  /// Character ID (primary key).
  IntColumn get characterId =>
      integer().references(Characters, #characterId)();

  /// Solar system ID where the character is located.
  IntColumn get solarSystemId => integer().nullable()();

  /// Solar system name (cached from SDE).
  TextColumn get solarSystemName => text().nullable()();

  /// Security status of the solar system (0.0 to 1.0).
  RealColumn get securityStatus => real().nullable()();

  /// Ship type ID the character is currently flying.
  IntColumn get shipTypeId => integer().nullable()();

  /// Ship type name (cached from SDE).
  TextColumn get shipTypeName => text().nullable()();

  /// Whether the character is currently online.
  BoolColumn get isOnline => boolean().withDefault(const Constant(false))();

  /// When the character last logged in.
  DateTimeColumn get lastLogin => dateTime().nullable()();

  /// When the character last logged out.
  DateTimeColumn get lastLogout => dateTime().nullable()();

  /// When this data was last refreshed from ESI.
  DateTimeColumn get lastUpdated => dateTime()();

  @override
  Set<Column> get primaryKey => {characterId};
}

/// Universe names cache for EVE entity name resolution.
///
/// Provides hybrid caching (memory + database) for resolving
/// EVE IDs to names (factions, corporations, stations, types, etc.).
/// Names are fetched from ESI /universe/names/ endpoint.
class UniverseNames extends Table {
  /// EVE ID (primary key).
  IntColumn get id => integer()();

  /// Resolved name.
  TextColumn get name => text()();

  /// Entity category ('character', 'corporation', 'alliance', 'faction',
  /// 'inventory_type', 'solar_system', 'station', etc.).
  TextColumn get category => text()();

  /// When this name was last fetched from ESI (Unix timestamp).
  IntColumn get lastUpdated => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached trained skills for characters.
///
/// Stores all trained skills with current levels and skill points.
/// Fetched from ESI /characters/{id}/skills/ endpoint.
class CharacterSkills extends Table {
  /// Auto-incrementing ID.
  IntColumn get id => integer().autoIncrement()();

  /// Character ID this skill belongs to.
  IntColumn get characterId =>
      integer().references(Characters, #characterId)();

  /// Skill type ID from EVE SDE.
  IntColumn get skillId => integer()();

  /// Trained skill level (0-5).
  IntColumn get trainedSkillLevel => integer()();

  /// Active skill level (same as trained unless in skillqueue).
  IntColumn get activeSkillLevel => integer()();

  /// Skill points in this skill.
  IntColumn get skillpointsInSkill => integer()();

  /// When this data was last fetched from ESI.
  DateTimeColumn get lastUpdated => dateTime()();
}

/// Local skill plans (not synced to ESI).
///
/// User-created training plans to track which skills to train.
/// Plans are stored locally and can contain any skills.
class SkillPlans extends Table {
  /// Auto-incrementing ID (primary key).
  IntColumn get id => integer().autoIncrement()();

  /// Character ID this plan belongs to.
  IntColumn get characterId =>
      integer().references(Characters, #characterId)();

  /// Plan name (e.g., "PvP Frigate", "Mining Barge").
  TextColumn get name => text()();

  /// Optional description of plan purpose.
  TextColumn get description => text().nullable()();

  /// When this plan was created.
  DateTimeColumn get createdAt => dateTime()();

  /// When this plan was last modified.
  DateTimeColumn get updatedAt => dateTime()();
}

/// Skills within a skill plan.
///
/// Each entry represents a skill at a target level in a plan.
/// Sort order determines the display/training order.
class SkillPlanEntries extends Table {
  /// Auto-incrementing ID.
  IntColumn get id => integer().autoIncrement()();

  /// Skill plan ID this entry belongs to.
  IntColumn get planId => integer().references(SkillPlans, #id)();

  /// Skill type ID from EVE SDE.
  IntColumn get skillId => integer()();

  /// Target level for this skill (1-5).
  IntColumn get targetLevel => integer()();

  /// Sort order within the plan (0 = first).
  IntColumn get sortOrder => integer()();
}

/// Application database using Drift.
///
/// Handles all local persistence for Mimir including:
/// - Character profiles and authentication state
/// - Skill queue caching
/// - Wallet transaction history
/// - Universe name resolution cache
@DriftDatabase(tables: [
  Characters,
  SkillQueueEntries,
  WalletJournalEntries,
  WalletBalances,
  WalletTransactions,
  LoyaltyPoints,
  AssetCache,
  AppSettingsTable,
  CombatStats,
  CharacterStatuses,
  UniverseNames,
  CharacterSkills,
  SkillPlans,
  SkillPlanEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with custom executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Insert default settings row.
        await into(appSettingsTable).insert(
          AppSettingsTableCompanion.insert(),
        );
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration from version 1 to 2: Add token storage columns.
        if (from < 2) {
          await m.addColumn(characters, characters.refreshToken);
          await m.addColumn(characters, characters.accessToken);
        }

        // Migration from version 2 to 3: Add app settings table.
        if (from < 3) {
          await m.createTable(appSettingsTable);
          // Insert default settings row.
          await into(appSettingsTable).insert(
            AppSettingsTableCompanion.insert(),
          );
        }

        // Migration from version 3 to 4: Add combat stats table.
        if (from < 4) {
          await m.createTable(combatStats);
        }

        // Migration from version 4 to 5: Add character statuses table.
        if (from < 5) {
          await m.createTable(characterStatuses);
        }

        // Migration from version 5 to 6: Add universe names cache table.
        if (from < 6) {
          await m.createTable(universeNames);
        }

        // Migration from version 6 to 7: Add faction ID and security status to characters.
        if (from < 7) {
          await m.addColumn(characters, characters.factionId);
          await m.addColumn(characters, characters.securityStatus);
        }

        // Migration from version 7 to 8: Add wallet enhancement tables.
        if (from < 8) {
          await m.createTable(walletTransactions);
          await m.createTable(loyaltyPoints);
          await m.createTable(assetCache);
        }

        // Migration from version 8 to 9: Add skills enhancement tables.
        if (from < 9) {
          await m.createTable(characterSkills);
          await m.createTable(skillPlans);
          await m.createTable(skillPlanEntries);
        }

        // Migration from version 9 to 10: Add ESI rate limit tracking.
        if (from < 10) {
          await m.addColumn(appSettingsTable, appSettingsTable.esiErrorLimitRemain);
          await m.addColumn(appSettingsTable, appSettingsTable.esiErrorLimitReset);
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
      await (delete(characterSkills)
            ..where((cs) => cs.characterId.equals(characterId)))
          .go();
      // Delete skill plan entries for plans owned by this character
      final plans = await (select(skillPlans)
            ..where((p) => p.characterId.equals(characterId)))
          .get();
      for (final plan in plans) {
        await (delete(skillPlanEntries)
              ..where((e) => e.planId.equals(plan.id)))
            .go();
      }
      await (delete(skillPlans)
            ..where((p) => p.characterId.equals(characterId)))
          .go();
      await (delete(walletJournalEntries)
            ..where((e) => e.characterId.equals(characterId)))
          .go();
      await (delete(walletBalances)
            ..where((e) => e.characterId.equals(characterId)))
          .go();
      await (delete(walletTransactions)
            ..where((e) => e.characterId.equals(characterId)))
          .go();
      await (delete(loyaltyPoints)
            ..where((e) => e.characterId.equals(characterId)))
          .go();
      await (delete(assetCache)
            ..where((e) => e.characterId.equals(characterId)))
          .go();
      await (delete(combatStats)
            ..where((s) => s.characterId.equals(characterId)))
          .go();
      await (delete(characterStatuses)
            ..where((s) => s.characterId.equals(characterId)))
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

  /// Get all skill queues for all characters.
  ///
  /// More efficient than querying each character individually (avoids N+1).
  /// Returns a map of characterId → skill queue entries.
  Future<Map<int, List<SkillQueueEntry>>> getAllSkillQueues() async {
    // Fetch all skill queue entries in a single query.
    final allEntries = await (select(skillQueueEntries)
          ..orderBy([(e) => OrderingTerm.asc(e.characterId), (e) => OrderingTerm.asc(e.queuePosition)]))
        .get();

    // Group by character ID.
    final queueMap = <int, List<SkillQueueEntry>>{};
    for (final entry in allEntries) {
      queueMap.putIfAbsent(entry.characterId, () => []).add(entry);
    }

    return queueMap;
  }

  // Character skills operations

  /// Replace trained skills for a character.
  ///
  /// Replaces all existing skills with the provided list. Use this when
  /// fetching skills from ESI to ensure the cache is up to date.
  Future<void> replaceCharacterSkills(
    int characterId,
    List<CharacterSkillsCompanion> skills,
  ) async {
    await transaction(() async {
      await (delete(characterSkills)
            ..where((cs) => cs.characterId.equals(characterId)))
          .go();
      await batch((b) {
        b.insertAll(characterSkills, skills);
      });
    });
  }

  /// Get all trained skills for a character.
  Future<List<CharacterSkill>> getCharacterSkills(int characterId) {
    return (select(characterSkills)
          ..where((cs) => cs.characterId.equals(characterId)))
        .get();
  }

  /// Watch trained skills for reactive updates.
  Stream<List<CharacterSkill>> watchCharacterSkills(int characterId) {
    return (select(characterSkills)
          ..where((cs) => cs.characterId.equals(characterId)))
        .watch();
  }

  /// Get a specific trained skill for a character.
  ///
  /// Returns null if the skill is not trained.
  Future<CharacterSkill?> getCharacterSkill(
    int characterId,
    int skillId,
  ) {
    return (select(characterSkills)
          ..where((cs) => cs.characterId.equals(characterId))
          ..where((cs) => cs.skillId.equals(skillId)))
        .getSingleOrNull();
  }

  /// Get total skill points for a character.
  ///
  /// Sums all skill points across all trained skills.
  Future<int> getTotalSkillpoints(int characterId) async {
    final skills = await getCharacterSkills(characterId);
    return skills.fold<int>(0, (sum, skill) => sum + skill.skillpointsInSkill);
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

  /// Get wallet journal entries since a specific date.
  ///
  /// More efficient than fetching all entries and filtering in memory.
  /// Uses SQL WHERE clause to filter at the database layer.
  Future<List<WalletJournalEntry>> getWalletJournalSince(
    int characterId,
    DateTime since,
  ) {
    return (select(walletJournalEntries)
          ..where((e) => e.characterId.equals(characterId))
          ..where((e) => e.date.isBiggerThanValue(since))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
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

  /// Get latest wallet balances for all characters.
  ///
  /// More efficient than querying each character individually (avoids N+1).
  /// Returns a map of characterId → balance.
  Future<Map<int, double>> getAllLatestWalletBalances() async {
    // Get the latest balance for each character using a subquery.
    // This is more efficient than N queries (one per character).
    final query = '''
      SELECT character_id, balance
      FROM wallet_balances wb1
      WHERE recorded_at = (
        SELECT MAX(recorded_at)
        FROM wallet_balances wb2
        WHERE wb2.character_id = wb1.character_id
      )
    ''';

    final result = await customSelect(query).get();
    final balanceMap = <int, double>{};

    for (final row in result) {
      final characterId = row.read<int>('character_id');
      final balance = row.read<double>('balance');
      balanceMap[characterId] = balance;
    }

    return balanceMap;
  }

  // Wallet transactions operations

  /// Insert wallet transactions (ignores duplicates).
  Future<void> insertWalletTransactions(
    List<WalletTransactionsCompanion> transactions,
  ) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(walletTransactions, transactions);
    });
  }

  /// Get wallet transactions for a character.
  Future<List<WalletTransaction>> getWalletTransactions(
    int characterId, {
    int limit = 100,
  }) {
    return (select(walletTransactions)
          ..where((t) => t.characterId.equals(characterId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(limit))
        .get();
  }

  /// Watch wallet transactions for reactive updates.
  Stream<List<WalletTransaction>> watchWalletTransactions(
    int characterId, {
    int limit = 100,
  }) {
    return (select(walletTransactions)
          ..where((t) => t.characterId.equals(characterId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(limit))
        .watch();
  }

  // Loyalty points operations

  /// Replace loyalty points for a character.
  Future<void> replaceLoyaltyPoints(
    int characterId,
    List<LoyaltyPointsCompanion> points,
  ) async {
    await transaction(() async {
      await (delete(loyaltyPoints)
            ..where((lp) => lp.characterId.equals(characterId)))
          .go();
      await batch((b) {
        b.insertAll(loyaltyPoints, points);
      });
    });
  }

  /// Get loyalty points for a character.
  Future<List<LoyaltyPoint>> getLoyaltyPoints(int characterId) {
    return (select(loyaltyPoints)
          ..where((lp) => lp.characterId.equals(characterId)))
        .get();
  }

  /// Watch loyalty points for reactive updates.
  Stream<List<LoyaltyPoint>> watchLoyaltyPoints(int characterId) {
    return (select(loyaltyPoints)
          ..where((lp) => lp.characterId.equals(characterId)))
        .watch();
  }

  // Asset cache operations

  /// Insert or update assets in cache.
  Future<void> upsertAssets(List<AssetCacheCompanion> assets) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(assetCache, assets);
    });
  }

  /// Get assets for a character (optionally filtered by type ID).
  Future<List<AssetCacheData>> getAssets(
    int characterId, {
    int? typeId,
  }) {
    final query = select(assetCache)
      ..where((a) => a.characterId.equals(characterId));

    if (typeId != null) {
      query.where((a) => a.typeId.equals(typeId));
    }

    return query.get();
  }

  /// Get PLEX count for a character (type_id 44992).
  Future<int> getPlexCount(int characterId) async {
    final plexAssets = await getAssets(characterId, typeId: 44992);
    return plexAssets.fold<int>(0, (sum, asset) => sum + asset.quantity);
  }

  /// Clear asset cache for a character.
  Future<void> clearAssetCache(int characterId) {
    return (delete(assetCache)
          ..where((a) => a.characterId.equals(characterId)))
        .go();
  }

  // App settings operations

  /// Get app settings (returns defaults if not found).
  Future<AppSettingsTableData> getAppSettings() async {
    final result = await (select(appSettingsTable)
          ..where((s) => s.id.equals(1)))
        .getSingleOrNull();

    if (result != null) return result;

    // Settings don't exist yet, insert defaults.
    await into(appSettingsTable).insert(
      AppSettingsTableCompanion.insert(),
    );
    return (await (select(appSettingsTable)
              ..where((s) => s.id.equals(1)))
            .getSingleOrNull()) ??
        const AppSettingsTableData(
          id: 1,
          startupBehavior: 'dashboard',
          onboardingComplete: false,
          esiErrorLimitRemain: 100,
          esiErrorLimitReset: null,
        );
  }

  /// Watch app settings for reactive updates.
  Stream<AppSettingsTableData> watchAppSettings() {
    return (select(appSettingsTable)..where((s) => s.id.equals(1)))
        .watchSingle();
  }

  /// Update app settings.
  Future<void> updateAppSettings(AppSettingsTableCompanion settings) {
    return (update(appSettingsTable)..where((s) => s.id.equals(1)))
        .write(settings);
  }

  // Combat stats operations

  /// Get combat stats for a character.
  Future<CombatStat?> getCombatStats(int characterId) {
    return (select(combatStats)..where((s) => s.characterId.equals(characterId)))
        .getSingleOrNull();
  }

  /// Get all combat stats.
  Future<List<CombatStat>> getAllCombatStats() {
    return select(combatStats).get();
  }

  /// Insert or update combat stats for a character.
  Future<void> upsertCombatStats(CombatStatsCompanion stats) {
    return into(combatStats).insertOnConflictUpdate(stats);
  }

  /// Delete combat stats for a character.
  Future<void> deleteCombatStats(int characterId) {
    return (delete(combatStats)..where((s) => s.characterId.equals(characterId)))
        .go();
  }

  // Character status operations

  /// Get character status for a specific character.
  Future<CharacterStatuse?> getCharacterStatus(int characterId) {
    return (select(characterStatuses)
          ..where((s) => s.characterId.equals(characterId)))
        .getSingleOrNull();
  }

  /// Get all character statuses.
  Future<List<CharacterStatuse>> getAllCharacterStatuses() {
    return select(characterStatuses).get();
  }

  /// Insert or update character status.
  Future<void> upsertCharacterStatus(CharacterStatusesCompanion status) {
    return into(characterStatuses).insertOnConflictUpdate(status);
  }

  /// Delete character status for a character.
  Future<void> deleteCharacterStatus(int characterId) {
    return (delete(characterStatuses)
          ..where((s) => s.characterId.equals(characterId)))
        .go();
  }

  // Universe names cache operations

  /// Get a universe name by ID.
  Future<UniverseName?> getUniverseName(int id) {
    return (select(universeNames)..where((n) => n.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get multiple universe names by IDs.
  Future<List<UniverseName>> getUniverseNames(List<int> ids) {
    return (select(universeNames)..where((n) => n.id.isIn(ids))).get();
  }

  /// Insert or update universe names (batch operation).
  Future<void> upsertUniverseNames(List<UniverseNamesCompanion> names) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(universeNames, names);
    });
  }

  /// Delete old universe names (older than specified timestamp).
  Future<void> deleteOldUniverseNames(int olderThanTimestamp) {
    return (delete(universeNames)
          ..where((n) => n.lastUpdated.isSmallerThanValue(olderThanTimestamp)))
        .go();
  }

  // Skill plans operations

  /// Create a new skill plan.
  ///
  /// Returns the ID of the newly created plan.
  Future<int> createSkillPlan({
    required int characterId,
    required String name,
    String? description,
  }) async {
    final now = DateTime.now();
    return await into(skillPlans).insert(
      SkillPlansCompanion.insert(
        characterId: characterId,
        name: name,
        description: Value(description),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Update a skill plan.
  Future<void> updateSkillPlan({
    required int planId,
    String? name,
    String? description,
  }) async {
    await (update(skillPlans)..where((p) => p.id.equals(planId))).write(
      SkillPlansCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete a skill plan and all its entries.
  Future<void> deleteSkillPlan(int planId) async {
    await transaction(() async {
      await (delete(skillPlanEntries)..where((e) => e.planId.equals(planId)))
          .go();
      await (delete(skillPlans)..where((p) => p.id.equals(planId))).go();
    });
  }

  /// Get all skill plans for a character.
  Future<List<SkillPlan>> getSkillPlans(int characterId) {
    return (select(skillPlans)
          ..where((p) => p.characterId.equals(characterId))
          ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]))
        .get();
  }

  /// Watch skill plans for reactive updates.
  Stream<List<SkillPlan>> watchSkillPlans(int characterId) {
    return (select(skillPlans)
          ..where((p) => p.characterId.equals(characterId))
          ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]))
        .watch();
  }

  /// Add a skill to a plan.
  Future<void> addSkillToPlan({
    required int planId,
    required int skillId,
    required int targetLevel,
    required int sortOrder,
  }) {
    return into(skillPlanEntries).insert(
      SkillPlanEntriesCompanion.insert(
        planId: planId,
        skillId: skillId,
        targetLevel: targetLevel,
        sortOrder: sortOrder,
      ),
    );
  }

  /// Remove a skill from a plan.
  Future<void> removeSkillFromPlan(int planId, int skillId) {
    return (delete(skillPlanEntries)
          ..where((e) => e.planId.equals(planId))
          ..where((e) => e.skillId.equals(skillId)))
        .go();
  }

  /// Update the sort order of skills in a plan.
  ///
  /// Takes a list of skill IDs in the desired order and updates sort order.
  Future<void> updatePlanEntryOrder(int planId, List<int> skillIds) async {
    await transaction(() async {
      for (var i = 0; i < skillIds.length; i++) {
        await (update(skillPlanEntries)
              ..where((e) => e.planId.equals(planId))
              ..where((e) => e.skillId.equals(skillIds[i])))
            .write(SkillPlanEntriesCompanion(sortOrder: Value(i)));
      }
    });
  }

  /// Get all entries for a skill plan.
  Future<List<SkillPlanEntry>> getPlanEntries(int planId) {
    return (select(skillPlanEntries)
          ..where((e) => e.planId.equals(planId))
          ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
        .get();
  }

  /// Watch skill plan entries for reactive updates.
  Stream<List<SkillPlanEntry>> watchPlanEntries(int planId) {
    return (select(skillPlanEntries)
          ..where((e) => e.planId.equals(planId))
          ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
        .watch();
  }
  /// Updates the ESI error limit remaining and reset timestamp.
  Future<void> updateEsiErrorLimit(int remain, DateTime? reset) async {
    await (update(appSettingsTable)..where((t) => t.id.equals(1))).write(
      AppSettingsTableCompanion(
        esiErrorLimitRemain: Value(remain),
        esiErrorLimitReset: Value(reset),
      ),
    );
  }

  /// Gets the current ESI error limit tracking state.
  Future<AppSettingsTableData> getEsiErrorLimit() async {
    final settings = await (select(appSettingsTable)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (settings != null) return settings;
    
    // Fallback if not seeded yet
    return const AppSettingsTableData(
      id: 1,
      startupBehavior: 'dashboard',
      onboardingComplete: false,
      esiErrorLimitRemain: 100,
      esiErrorLimitReset: null,
    );
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
