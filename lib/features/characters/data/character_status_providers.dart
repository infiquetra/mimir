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
