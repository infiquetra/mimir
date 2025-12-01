import 'package:drift/drift.dart';
import 'package:mimir/core/database/app_database.dart' as db;
import 'package:mimir/core/logging/logger.dart';
import 'package:mimir/core/network/esi_client.dart';

/// Repository for aggregating and caching character status data.
///
/// Provides:
/// - Character clones (jump clones + home location)
/// - Active implants with resolved names
/// - Standings with resolved faction/corp names
/// - Hybrid name caching (memory + database)
class CharacterStatusRepository {
  final db.AppDatabase _database;
  final EsiClient _esiClient;

  /// In-memory cache for universe names (fast reads).
  /// Uses database UniverseName type for consistency.
  final Map<int, db.UniverseName> _nameCache = {};

  CharacterStatusRepository({
    required db.AppDatabase database,
    required EsiClient esiClient,
  })  : _database = database,
        _esiClient = esiClient;

  // ==========================================================================
  // Character Clones
  // ==========================================================================

  /// Fetches and returns character clones from ESI.
  ///
  /// Does not cache to database - clones change infrequently and
  /// we want fresh data each time.
  Future<CharacterClones> getCharacterClones(int characterId) async {
    Log.d('CHAR.CLONES', 'getCharacterClones($characterId) - START');
    try {
      final clones = await _esiClient.getCharacterClones(characterId);
      Log.i('CHAR.CLONES',
          'Fetched ${clones.jumpClones.length} jump clones from ESI');
      return clones;
    } catch (e, stack) {
      Log.e('CHAR.CLONES', 'getCharacterClones($characterId) - FAILED',
          e, stack);
      rethrow;
    }
  }

  // ==========================================================================
  // Character Implants
  // ==========================================================================

  /// Fetches character implants and resolves type names.
  ///
  /// Returns a map of implant type ID to name.
  Future<Map<int, String>> getCharacterImplantsWithNames(
    int characterId,
  ) async {
    Log.d('CHAR.IMPLANTS', 'getCharacterImplantsWithNames($characterId) - START');
    try {
      // Fetch implant type IDs from ESI.
      final implantIds = await _esiClient.getCharacterImplants(characterId);
      Log.i('CHAR.IMPLANTS', 'Fetched ${implantIds.length} implant IDs');

      if (implantIds.isEmpty) {
        return {};
      }

      // Resolve names.
      final names = await resolveNames(implantIds);

      // Build map of ID to name.
      final result = <int, String>{};
      for (final name in names) {
        result[name.id] = name.name;
      }

      Log.d('CHAR.IMPLANTS', 'getCharacterImplantsWithNames($characterId) - SUCCESS');
      return result;
    } catch (e, stack) {
      Log.e('CHAR.IMPLANTS',
          'getCharacterImplantsWithNames($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  // ==========================================================================
  // Character Standings
  // ==========================================================================

  /// Fetches character standings and resolves entity names.
  ///
  /// Returns standings with resolved names.
  Future<List<StandingWithName>> getCharacterStandingsWithNames(
    int characterId,
  ) async {
    Log.d('CHAR.STANDINGS',
        'getCharacterStandingsWithNames($characterId) - START');
    try {
      // Fetch standings from ESI.
      final standings = await _esiClient.getCharacterStandings(characterId);
      Log.i('CHAR.STANDINGS', 'Fetched ${standings.length} standings');

      if (standings.isEmpty) {
        return [];
      }

      // Extract IDs to resolve.
      final ids = standings.map((s) => s.fromId).toList();

      // Resolve names.
      final names = await resolveNames(ids);

      // Build ID to name map.
      final nameMap = <int, String>{};
      for (final name in names) {
        nameMap[name.id] = name.name;
      }

      // Combine standings with names.
      final result = standings.map((standing) {
        return StandingWithName(
          fromId: standing.fromId,
          fromType: standing.fromType,
          standing: standing.standing,
          name: nameMap[standing.fromId] ?? 'Unknown',
        );
      }).toList();

      Log.d('CHAR.STANDINGS',
          'getCharacterStandingsWithNames($characterId) - SUCCESS');
      return result;
    } catch (e, stack) {
      Log.e('CHAR.STANDINGS',
          'getCharacterStandingsWithNames($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  // ==========================================================================
  // Hybrid Name Resolution (Memory + Database + ESI)
  // ==========================================================================

  /// Resolves a list of IDs to names using hybrid caching.
  ///
  /// Strategy:
  /// 1. Check memory cache
  /// 2. Check database cache
  /// 3. Fetch from ESI and cache both
  ///
  /// Returns database UniverseName objects for consistency.
  Future<List<db.UniverseName>> resolveNames(List<int> ids) async {
    if (ids.isEmpty) return [];

    Log.d('NAME.RESOLVE', 'resolveNames(${ids.length} IDs) - START');

    final result = <db.UniverseName>[];
    final missingIds = <int>[];

    // Step 1: Check memory cache.
    for (final id in ids) {
      if (_nameCache.containsKey(id)) {
        result.add(_nameCache[id]!);
      } else {
        missingIds.add(id);
      }
    }

    if (missingIds.isEmpty) {
      Log.d('NAME.RESOLVE', 'All ${ids.length} names found in memory cache');
      return result;
    }

    Log.d('NAME.RESOLVE',
        '${missingIds.length} names missing from memory, checking database');

    // Step 2: Check database cache.
    final dbNames = await _database.getUniverseNames(missingIds);
    result.addAll(dbNames);

    // Update memory cache with database hits.
    for (final name in dbNames) {
      _nameCache[name.id] = name;
    }

    // Find IDs still missing after database check.
    final dbIds = dbNames.map((n) => n.id).toSet();
    final stillMissing = missingIds.where((id) => !dbIds.contains(id)).toList();

    if (stillMissing.isEmpty) {
      Log.d('NAME.RESOLVE',
          'All ${ids.length} names resolved (memory + database)');
      return result;
    }

    Log.i('NAME.RESOLVE',
        '${stillMissing.length} names missing, fetching from ESI');

    // Step 3: Fetch from ESI.
    final esiNames = await _esiClient.getUniverseNames(stillMissing);

    // Step 4: Convert ESI names to database format and cache.
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final companions = esiNames.map((esiName) {
      return db.UniverseNamesCompanion.insert(
        id: esiName.id,
        name: esiName.name,
        category: esiName.category,
        lastUpdated: now,
      );
    }).toList();

    await _database.upsertUniverseNames(companions);

    // Fetch the newly inserted records from database to get proper db.UniverseName objects.
    final newDbNames = await _database.getUniverseNames(stillMissing);
    result.addAll(newDbNames);

    // Update memory cache with database objects.
    for (final name in newDbNames) {
      _nameCache[name.id] = name;
    }

    Log.d('NAME.RESOLVE',
        'Resolved ${ids.length} names total (${esiNames.length} from ESI)');
    return result;
  }

  /// Resolves a single ID to a name.
  Future<String?> resolveName(int id) async {
    final names = await resolveNames([id]);
    return names.isEmpty ? null : names.first.name;
  }

  /// Clears old entries from the name cache.
  ///
  /// Removes entries older than [daysOld] from the database.
  /// Memory cache is not affected.
  Future<void> clearOldNameCache({int daysOld = 30}) async {
    Log.i('NAME.CACHE', 'Clearing name cache entries older than $daysOld days');
    final cutoff = DateTime.now()
        .subtract(Duration(days: daysOld))
        .millisecondsSinceEpoch ~/ 1000;
    await _database.deleteOldUniverseNames(cutoff);
  }
}

/// Standing with resolved name.
class StandingWithName {
  final int fromId;
  final String fromType;
  final double standing;
  final String name;

  const StandingWithName({
    required this.fromId,
    required this.fromType,
    required this.standing,
    required this.name,
  });
}
