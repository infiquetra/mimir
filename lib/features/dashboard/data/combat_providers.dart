import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../characters/data/character_providers.dart';
import 'zkillboard_client.dart';

/// Minimum time between zkillboard API fetches (1 hour).
const Duration _cacheExpiry = Duration(hours: 1);

/// Data model for combat statistics from a single character.
class CombatStatsData {
  final int characterId;
  final String characterName;
  final int kills;
  final int deaths;
  final double iskDestroyed;
  final double iskLost;

  const CombatStatsData({
    required this.characterId,
    required this.characterName,
    required this.kills,
    required this.deaths,
    required this.iskDestroyed,
    required this.iskLost,
  });

  /// K/D ratio (kills / deaths). Returns 0 if no deaths.
  double get kdRatio {
    if (deaths == 0) {
      return kills.toDouble();
    }
    return kills / deaths;
  }

  /// Danger rating (kills - deaths).
  int get dangerRating => kills - deaths;

  /// Net ISK (destroyed - lost).
  double get netIsk => iskDestroyed - iskLost;

  /// Whether this character has any combat activity.
  bool get hasActivity => kills > 0 || deaths > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CombatStatsData &&
          runtimeType == other.runtimeType &&
          characterId == other.characterId &&
          characterName == other.characterName &&
          kills == other.kills &&
          deaths == other.deaths &&
          iskDestroyed == other.iskDestroyed &&
          iskLost == other.iskLost;

  @override
  int get hashCode =>
      characterId.hashCode ^
      characterName.hashCode ^
      kills.hashCode ^
      deaths.hashCode ^
      iskDestroyed.hashCode ^
      iskLost.hashCode;
}

/// Data model for aggregated combat statistics across all characters.
class AggregateCombatStats {
  final int totalKills;
  final int totalDeaths;
  final double totalIskDestroyed;
  final double totalIskLost;
  final List<CombatStatsData> characterStats;

  const AggregateCombatStats({
    required this.totalKills,
    required this.totalDeaths,
    required this.totalIskDestroyed,
    required this.totalIskLost,
    required this.characterStats,
  });

  /// Overall K/D ratio across all characters.
  double get kdRatio {
    if (totalDeaths == 0) {
      return totalKills.toDouble();
    }
    return totalKills / totalDeaths;
  }

  /// Overall danger rating across all characters.
  int get dangerRating => totalKills - totalDeaths;

  /// Net ISK across all characters.
  double get netIsk => totalIskDestroyed - totalIskLost;

  /// Whether any character has combat activity.
  bool get hasActivity => totalKills > 0 || totalDeaths > 0;

  /// Number of characters with combat data.
  int get activeCharacterCount =>
      characterStats.where((s) => s.hasActivity).length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AggregateCombatStats &&
          runtimeType == other.runtimeType &&
          totalKills == other.totalKills &&
          totalDeaths == other.totalDeaths &&
          totalIskDestroyed == other.totalIskDestroyed &&
          totalIskLost == other.totalIskLost &&
          characterStats.length == other.characterStats.length;

  @override
  int get hashCode =>
      totalKills.hashCode ^
      totalDeaths.hashCode ^
      totalIskDestroyed.hashCode ^
      totalIskLost.hashCode ^
      characterStats.hashCode;
}

/// Provider that fetches combat stats for a single character.
///
/// Returns cached stats if less than 1 hour old, otherwise fetches
/// from zkillboard API and caches the result.
///
/// Returns null if the character has no killboard data (404 from zkillboard).
final combatStatsProvider =
    FutureProvider.family<CombatStatsData?, int>((ref, characterId) async {
  final database = ref.watch(databaseProvider);
  final zkillboardClient = ref.watch(zkillboardClientProvider);
  final characters = await ref.watch(allCharactersProvider.future);

  // Find character name.
  final character = characters.firstWhere(
    (c) => c.characterId == characterId,
    orElse: () => throw Exception('Character not found: $characterId'),
  );

  // Check cache first.
  final cached = await database.getCombatStats(characterId);
  if (cached != null) {
    final age = DateTime.now().difference(cached.lastUpdated);
    if (age < _cacheExpiry) {
      // Cache is still fresh, return cached data.
      return CombatStatsData(
        characterId: cached.characterId,
        characterName: character.name,
        kills: cached.kills,
        deaths: cached.deaths,
        iskDestroyed: cached.iskDestroyed,
        iskLost: cached.iskLost,
      );
    }
  }

  // Cache is stale or missing, fetch from zkillboard.
  try {
    final stats = await zkillboardClient.getCharacterStats(characterId);

    if (stats == null) {
      // Character has no killboard data (404 from zkillboard).
      // Cache a zero-stats entry to avoid repeated API calls.
      await database.upsertCombatStats(
        CombatStatsCompanion.insert(
          characterId: Value(characterId),
          kills: const Value(0),
          deaths: const Value(0),
          iskDestroyed: const Value(0.0),
          iskLost: const Value(0.0),
          lastUpdated: DateTime.now(),
        ),
      );
      return null;
    }

    // Cache the fetched stats.
    await database.upsertCombatStats(
      CombatStatsCompanion.insert(
        characterId: Value(characterId),
        kills: Value(stats.kills),
        deaths: Value(stats.deaths),
        iskDestroyed: Value(stats.iskDestroyed),
        iskLost: Value(stats.iskLost),
        lastUpdated: DateTime.now(),
      ),
    );

    return CombatStatsData(
      characterId: characterId,
      characterName: character.name,
      kills: stats.kills,
      deaths: stats.deaths,
      iskDestroyed: stats.iskDestroyed,
      iskLost: stats.iskLost,
    );
  } on ZkillboardException {
    // Log error but don't fail the entire dashboard.
    // Return cached data if available, otherwise null.
    if (cached != null) {
      return CombatStatsData(
        characterId: cached.characterId,
        characterName: character.name,
        kills: cached.kills,
        deaths: cached.deaths,
        iskDestroyed: cached.iskDestroyed,
        iskLost: cached.iskLost,
      );
    }

    // No cached data and API failed - return null to indicate no data.
    // Don't throw to avoid blocking the dashboard.
    return null;
  }
});

/// Provider that aggregates combat stats across all characters.
///
/// Fetches stats for each character and aggregates totals.
/// Excludes characters with no combat data (null stats).
final allCharacterCombatStatsProvider =
    FutureProvider<AggregateCombatStats>((ref) async {
  final characters = await ref.watch(allCharactersProvider.future);

  // Fetch stats for all characters in parallel.
  final statsFutures = characters.map((char) {
    return ref.watch(combatStatsProvider(char.characterId).future);
  }).toList();

  final allStats = await Future.wait(statsFutures);

  // Filter out null stats (characters with no combat data).
  final validStats = allStats.whereType<CombatStatsData>().toList();

  // Calculate aggregates.
  int totalKills = 0;
  int totalDeaths = 0;
  double totalIskDestroyed = 0.0;
  double totalIskLost = 0.0;

  for (final stats in validStats) {
    totalKills += stats.kills;
    totalDeaths += stats.deaths;
    totalIskDestroyed += stats.iskDestroyed;
    totalIskLost += stats.iskLost;
  }

  return AggregateCombatStats(
    totalKills: totalKills,
    totalDeaths: totalDeaths,
    totalIskDestroyed: totalIskDestroyed,
    totalIskLost: totalIskLost,
    characterStats: validStats,
  );
});
