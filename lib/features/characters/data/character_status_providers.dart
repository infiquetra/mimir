import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import 'character_status_repository.dart';

part 'character_status_providers.g.dart';

// ==========================================================================
// Repository Provider
// ==========================================================================

/// Provider for the character status repository.
@riverpod
CharacterStatusRepository characterStatusRepository(
  Ref ref,
) {
  return CharacterStatusRepository(
    database: ref.watch(databaseProvider),
    esiClient: ref.watch(esiClientProvider),
  );
}

// ==========================================================================
// Character Clones Provider
// ==========================================================================

/// Provides character clones (jump clones + home location).
@riverpod
Future<CharacterClones> characterClones(
  Ref ref,
  int characterId,
) async {
  Log.d('PROVIDERS', 'characterClones($characterId) - START');
  final repository = ref.watch(characterStatusRepositoryProvider);
  return repository.getCharacterClones(characterId);
}

// ==========================================================================
// Character Implants Provider
// ==========================================================================

/// Provides character implants with resolved type names.
///
/// Returns a map of implant type ID to name.
@riverpod
Future<Map<int, String>> characterImplants(
  Ref ref,
  int characterId,
) async {
  Log.d('PROVIDERS', 'characterImplants($characterId) - START');
  final repository = ref.watch(characterStatusRepositoryProvider);
  return repository.getCharacterImplantsWithNames(characterId);
}

// ==========================================================================
// Character Standings Provider
// ==========================================================================

/// Provides character standings with resolved entity names.
@riverpod
Future<List<StandingWithName>> characterStandings(
  Ref ref,
  int characterId,
) async {
  Log.d('PROVIDERS', 'characterStandings($characterId) - START');
  final repository = ref.watch(characterStatusRepositoryProvider);
  return repository.getCharacterStandingsWithNames(characterId);
}

// ==========================================================================
// Character Attributes Provider
// ==========================================================================

/// Provides character attributes (already implemented in ESI client).
@riverpod
Future<CharacterAttributes> characterAttributes(
  Ref ref,
  int characterId,
) async {
  Log.d('PROVIDERS', 'characterAttributes($characterId) - START');
  final esiClient = ref.watch(esiClientProvider);
  return esiClient.getCharacterAttributes(characterId);
}

// ==========================================================================
// Character Clone Location Names Provider
// ==========================================================================

/// Provides resolved location names for character clones.
///
/// Returns a map of location ID → location name for all clone locations
/// (home location + all jump clone locations).
@riverpod
Future<Map<int, String>> characterCloneLocationNames(
  Ref ref,
  int characterId,
) async {
  Log.d('PROVIDERS', 'characterCloneLocationNames($characterId) - START');
  final repository = ref.watch(characterStatusRepositoryProvider);
  final clones = await ref.watch(characterClonesProvider(characterId).future);

  // Separate station IDs from structure IDs.
  // Stations: NPC stations (int32) resolved via /universe/names/
  // Structures: Player-owned (int64) resolved via /universe/structures/{id}/
  // Using Set to automatically deduplicate (multiple clones in same location)
  final stationIds = <int>{};
  final structureIds = <int>{};

  if (clones.homeLocation?.locationId != null) {
    if (clones.homeLocation!.locationType == 'station') {
      stationIds.add(clones.homeLocation!.locationId!);
    } else {
      structureIds.add(clones.homeLocation!.locationId!);
    }
  }

  for (final clone in clones.jumpClones) {
    if (clone.locationId != null) {
      if (clone.locationType == 'station') {
        stationIds.add(clone.locationId!);
      } else {
        structureIds.add(clone.locationId!);
      }
    }
  }

  // Resolve both types of locations.
  if (stationIds.isEmpty && structureIds.isEmpty) {
    Log.d('PROVIDERS', 'characterCloneLocationNames($characterId) - No IDs to resolve');
    return {};
  }

  Log.d('PROVIDERS', 'characterCloneLocationNames($characterId) - Resolving ${stationIds.length} stations, ${structureIds.length} structures');

  // Resolve stations via /universe/names/ endpoint.
  final stationNames = await repository.resolveNames(stationIds.toList());
  final stationNameMap = {for (var n in stationNames) n.id: n.name};

  // Resolve structures via authenticated /universe/structures/ endpoint.
  final structureNameMap = await repository.resolveStructureNames(
    structureIds.toList(),
    characterId,
  );

  // Merge both maps.
  final nameMap = {...stationNameMap, ...structureNameMap};

  Log.d('PROVIDERS', 'characterCloneLocationNames($characterId) - Resolved ${nameMap.length} names total');
  return nameMap;
}

// ==========================================================================
// Character Online Status Provider
// ==========================================================================

/// Provides aggregated online status including location and ship.
@riverpod
Future<OnlineStatus> characterOnlineStatus(
  Ref ref,
  int characterId,
) async {
  Log.d('PROVIDERS', 'characterOnlineStatus($characterId) - START');
  final esiClient = ref.watch(esiClientProvider);
  final repository = ref.watch(characterStatusRepositoryProvider);

  try {
    // Fetch all data in parallel.
    final results = await Future.wait<dynamic>([
      esiClient.getCharacterOnline(characterId),
      esiClient.getCharacterLocation(characterId),
      esiClient.getCharacterShip(characterId),
    ]);

    final online = results[0] as CharacterOnline;
    final location = results[1] as CharacterLocation?;
    final ship = results[2] as CharacterShip?;

    // Resolve names if we have IDs.
    String? systemName;
    String? stationName;
    String? shipTypeName;

    final idsToResolve = <int>[];
    if (location?.solarSystemId != null) {
      idsToResolve.add(location!.solarSystemId);
    }
    if (location?.stationId != null) {
      idsToResolve.add(location!.stationId!);
    }
    if (ship?.shipTypeId != null) {
      idsToResolve.add(ship!.shipTypeId);
    }

    if (idsToResolve.isNotEmpty) {
      final names = await repository.resolveNames(idsToResolve);
      final nameMap = {for (var n in names) n.id: n.name};

      if (location?.solarSystemId != null) {
        systemName = nameMap[location!.solarSystemId];
      }
      if (location?.stationId != null) {
        stationName = nameMap[location!.stationId!];
      }
      if (ship?.shipTypeId != null) {
        shipTypeName = nameMap[ship!.shipTypeId];
      }
    }

    return OnlineStatus(
      online: online.online,
      lastLogin: online.lastLogin,
      lastLogout: online.lastLogout,
      solarSystemId: location?.solarSystemId,
      solarSystemName: systemName,
      stationId: location?.stationId,
      stationName: stationName,
      shipTypeId: ship?.shipTypeId,
      shipTypeName: shipTypeName,
    );
  } catch (e, stack) {
    Log.e('PROVIDERS', 'characterOnlineStatus($characterId) - FAILED', e, stack);
    rethrow;
  }
}

/// Aggregated online status with location and ship information.
class OnlineStatus {
  final bool online;
  final DateTime? lastLogin;
  final DateTime? lastLogout;
  final int? solarSystemId;
  final String? solarSystemName;
  final int? stationId;
  final String? stationName;
  final int? shipTypeId;
  final String? shipTypeName;

  const OnlineStatus({
    required this.online,
    this.lastLogin,
    this.lastLogout,
    this.solarSystemId,
    this.solarSystemName,
    this.stationId,
    this.stationName,
    this.shipTypeId,
    this.shipTypeName,
  });
}
