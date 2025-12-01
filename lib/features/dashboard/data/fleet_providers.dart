import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import '../../../core/sde/sde_providers.dart';
import '../../characters/data/character_providers.dart';

/// Minimum time between fleet status fetches (5 minutes).
const Duration _cacheExpiry = Duration(minutes: 5);

/// Data model for character fleet status.
class CharacterStatusData {
  final int characterId;
  final String characterName;
  final String? solarSystemName;
  final double? securityStatus;
  final String? shipTypeName;
  final bool isOnline;
  final DateTime? lastLogin;
  final DateTime? lastLogout;

  const CharacterStatusData({
    required this.characterId,
    required this.characterName,
    this.solarSystemName,
    this.securityStatus,
    this.shipTypeName,
    required this.isOnline,
    this.lastLogin,
    this.lastLogout,
  });

  /// Returns true if character is in dangerous space (lowsec/nullsec).
  bool get isInDangerousSpace {
    if (securityStatus == null) return false;
    return securityStatus! < 0.5;
  }

  /// Returns security status color-coded description.
  String get securityStatusDescription {
    if (securityStatus == null) return 'Unknown';
    if (securityStatus! >= 0.5) return 'High Sec';
    if (securityStatus! > 0.0) return 'Low Sec';
    return 'Null Sec';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterStatusData &&
          runtimeType == other.runtimeType &&
          characterId == other.characterId &&
          characterName == other.characterName &&
          solarSystemName == other.solarSystemName &&
          securityStatus == other.securityStatus &&
          shipTypeName == other.shipTypeName &&
          isOnline == other.isOnline;

  @override
  int get hashCode =>
      characterId.hashCode ^
      characterName.hashCode ^
      solarSystemName.hashCode ^
      securityStatus.hashCode ^
      shipTypeName.hashCode ^
      isOnline.hashCode;
}

/// Data model for aggregated fleet status across all characters.
class AggregateFleetStatus {
  final int totalCharacters;
  final int onlineCharacters;
  final int offlineCharacters;
  final List<CharacterStatusData> characterStatuses;

  const AggregateFleetStatus({
    required this.totalCharacters,
    required this.onlineCharacters,
    required this.offlineCharacters,
    required this.characterStatuses,
  });

  /// Percentage of characters online (0.0 to 1.0).
  double get onlinePercentage {
    if (totalCharacters == 0) return 0.0;
    return onlineCharacters / totalCharacters;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AggregateFleetStatus &&
          runtimeType == other.runtimeType &&
          totalCharacters == other.totalCharacters &&
          onlineCharacters == other.onlineCharacters &&
          offlineCharacters == other.offlineCharacters &&
          characterStatuses.length == other.characterStatuses.length;

  @override
  int get hashCode =>
      totalCharacters.hashCode ^
      onlineCharacters.hashCode ^
      offlineCharacters.hashCode ^
      characterStatuses.hashCode;
}

/// Provider that fetches fleet status for a single character.
///
/// Returns cached status if less than 5 minutes old, otherwise fetches
/// from ESI and caches the result.
///
/// Handles missing scopes gracefully by returning null.
final characterFleetStatusProvider =
    FutureProvider.family<CharacterStatusData?, int>((ref, characterId) async {
  Log.d('FLEET', 'characterFleetStatusProvider($characterId) - START');
  final database = ref.watch(databaseProvider);
  final esiClient = ref.watch(esiClientProvider);
  final characters = await ref.watch(allCharactersProvider.future);

  // Find character name.
  final character = characters.firstWhere(
    (c) => c.characterId == characterId,
    orElse: () => throw Exception('Character not found: $characterId'),
  );

  // Check cache first.
  final cached = await database.getCharacterStatus(characterId);
  if (cached != null) {
    final age = DateTime.now().difference(cached.lastUpdated);
    if (age < _cacheExpiry) {
      // Cache is still fresh, return cached data.
      Log.d('FLEET', 'characterFleetStatusProvider - using cached data (age: ${age.inMinutes}min)');
      return CharacterStatusData(
        characterId: cached.characterId,
        characterName: character.name,
        solarSystemName: cached.solarSystemName,
        securityStatus: cached.securityStatus,
        shipTypeName: cached.shipTypeName,
        isOnline: cached.isOnline,
        lastLogin: cached.lastLogin,
        lastLogout: cached.lastLogout,
      );
    }
  }

  // Cache is stale or missing, fetch from ESI.
  try {
    Log.d('FLEET', 'characterFleetStatusProvider - fetching from ESI');
    // Fetch all status data in parallel.
    final results = await Future.wait([
      esiClient.getCharacterOnline(characterId),
      esiClient.getCharacterLocation(characterId),
      esiClient.getCharacterShip(characterId),
    ]);

    final online = results[0] as CharacterOnline;
    final location = results[1] as CharacterLocation?;
    final ship = results[2] as CharacterShip?;

    // Look up ship type name from SDE if we have a ship.
    String? shipTypeName;
    if (ship != null) {
      final sdeService = ref.read(sdeServiceProvider);
      shipTypeName = await sdeService.getShipTypeName(ship.shipTypeId);
    }

    Log.i('FLEET', 'characterFleetStatusProvider - fetched ESI data: online=${online.online}, location=${location?.solarSystemId}, ship=$shipTypeName');

    // Fetch solar system info if we have a location.
    String? systemName;
    double? secStatus;
    if (location != null) {
      try {
        final systemInfo =
            await esiClient.getSolarSystemInfo(location.solarSystemId);
        systemName = systemInfo.name;
        secStatus = systemInfo.securityStatus;
      } catch (e) {
        // Solar system lookup failed - use placeholder.
        systemName = 'System #${location.solarSystemId}';
      }
    }

    // Cache the fetched status.
    await database.upsertCharacterStatus(
      CharacterStatusesCompanion.insert(
        characterId: Value(characterId),
        solarSystemId: Value(location?.solarSystemId),
        solarSystemName: Value(systemName),
        securityStatus: Value(secStatus),
        shipTypeId: Value(ship?.shipTypeId),
        shipTypeName: Value(shipTypeName),
        isOnline: Value(online.online),
        lastLogin: Value(online.lastLogin),
        lastLogout: Value(online.lastLogout),
        lastUpdated: DateTime.now(),
      ),
    );

    Log.i('FLEET', 'characterFleetStatusProvider($characterId) - SUCCESS');
    return CharacterStatusData(
      characterId: characterId,
      characterName: character.name,
      solarSystemName: systemName,
      securityStatus: secStatus,
      shipTypeName: shipTypeName,
      isOnline: online.online,
      lastLogin: online.lastLogin,
      lastLogout: online.lastLogout,
    );
  } on EsiException catch (e, stack) {
    // Handle missing scopes gracefully.
    if (e.isScopeError) {
      Log.w('FLEET', 'characterFleetStatusProvider - missing OAuth scopes for character $characterId');
      // User hasn't re-authenticated with new scopes.
      // Return cached data if available, otherwise null.
      if (cached != null) {
        Log.d('FLEET', 'characterFleetStatusProvider - returning cached data due to scope error');
        return CharacterStatusData(
          characterId: cached.characterId,
          characterName: character.name,
          solarSystemName: cached.solarSystemName,
          securityStatus: cached.securityStatus,
          shipTypeName: cached.shipTypeName,
          isOnline: cached.isOnline,
          lastLogin: cached.lastLogin,
          lastLogout: cached.lastLogout,
        );
      }
      Log.d('FLEET', 'characterFleetStatusProvider - no cached data, returning null due to scope error');
      return null;
    }

    // Log error but don't fail the entire dashboard.
    Log.e('FLEET', 'characterFleetStatusProvider($characterId) - ESI error', e, stack);
    // Return cached data if available, otherwise null.
    if (cached != null) {
      Log.d('FLEET', 'characterFleetStatusProvider - returning cached data due to ESI error');
      return CharacterStatusData(
        characterId: cached.characterId,
        characterName: character.name,
        solarSystemName: cached.solarSystemName,
        securityStatus: cached.securityStatus,
        shipTypeName: cached.shipTypeName,
        isOnline: cached.isOnline,
        lastLogin: cached.lastLogin,
        lastLogout: cached.lastLogout,
      );
    }

    // No cached data and API failed - return null to indicate no data.
    // Don't throw to avoid blocking the dashboard.
    Log.w('FLEET', 'characterFleetStatusProvider - no cached data, returning null due to ESI error');
    return null;
  } catch (e, stack) {
    // Catch any other unexpected errors (parsing, database, type casting, etc.)
    Log.e('FLEET', 'characterFleetStatusProvider($characterId) - unexpected error', e, stack);

    // Return cached data if available, otherwise null.
    if (cached != null) {
      Log.d('FLEET', 'characterFleetStatusProvider - returning cached data due to unexpected error');
      return CharacterStatusData(
        characterId: cached.characterId,
        characterName: character.name,
        solarSystemName: cached.solarSystemName,
        securityStatus: cached.securityStatus,
        shipTypeName: cached.shipTypeName,
        isOnline: cached.isOnline,
        lastLogin: cached.lastLogin,
        lastLogout: cached.lastLogout,
      );
    }

    // No cached data and unexpected error - return null to avoid blocking dashboard.
    Log.w('FLEET', 'characterFleetStatusProvider - no cached data, returning null due to unexpected error');
    return null;
  }
});

/// Provider that aggregates fleet status across all characters.
///
/// Fetches status for each character and aggregates totals.
/// Excludes characters with no status data (null status).
final allCharacterFleetStatusProvider =
    FutureProvider<AggregateFleetStatus>((ref) async {
  Log.d('FLEET', 'allCharacterFleetStatusProvider - START');
  final characters = await ref.watch(allCharactersProvider.future);
  Log.i('FLEET', 'allCharacterFleetStatusProvider - fetching status for ${characters.length} characters');

  // Fetch statuses for all characters in parallel.
  final statusFutures = characters.map((char) {
    return ref.watch(characterFleetStatusProvider(char.characterId).future);
  }).toList();

  final allStatuses = await Future.wait(statusFutures);

  // Filter out null statuses (characters with no data or missing scopes).
  final validStatuses = allStatuses.whereType<CharacterStatusData>().toList();
  Log.d('FLEET', 'allCharacterFleetStatusProvider - received ${validStatuses.length} valid statuses out of ${allStatuses.length}');

  // Calculate aggregates.
  int onlineCount = 0;
  for (final status in validStatuses) {
    if (status.isOnline) onlineCount++;
  }

  Log.i('FLEET', 'allCharacterFleetStatusProvider - SUCCESS: $onlineCount online, ${validStatuses.length - onlineCount} offline (total: ${validStatuses.length})');
  return AggregateFleetStatus(
    totalCharacters: validStatuses.length,
    onlineCharacters: onlineCount,
    offlineCharacters: validStatuses.length - onlineCount,
    characterStatuses: validStatuses,
  );
});
