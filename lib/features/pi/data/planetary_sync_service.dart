import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import 'planetary_repository.dart';

/// Service for synchronizing Planetary Industry (PI) data from ESI.
class PlanetarySyncService {
  final EsiClient _esiClient;
  final PlanetaryRepository _repository;

  PlanetarySyncService({
    required EsiClient esiClient,
    required PlanetaryRepository repository,
  })  : _esiClient = esiClient,
        _repository = repository;

  /// Synchronizes all colonies and their pins for a character.
  Future<void> syncColonies(int characterId) async {
    Log.d('PI.SYNC', 'syncColonies($characterId) - START');
    try {
      // 1. Fetch colonies from ESI
      final esiColonies = await _esiClient.getCharacterPlanets(characterId);
      Log.i('PI.SYNC', 'Fetched ${esiColonies.length} colonies from ESI');

      final coloniesCompanions = <PlanetaryColoniesCompanion>[];
      final pinsCompanions = <PlanetaryPinsCompanion>[];

      // 2. Fetch pins for each colony
      for (final esiColony in esiColonies) {
        coloniesCompanions.add(PlanetaryColoniesCompanion.insert(
          planetId: esiColony.planetId,
          characterId: characterId,
          planetName: 'Planet ${esiColony.planetId}', // ESI doesn't provide name here
          planetType: esiColony.planetType,
          upgradeLevel: esiColony.upgradeLevel,
          numPins: esiColony.numPins,
          lastUpdate: esiColony.lastUpdate,
        ));

        final esiPins = await _esiClient.getCharacterPlanetPins(
          characterId,
          esiColony.planetId,
        );
        Log.d('PI.SYNC', 'Fetched ${esiPins.length} pins for planet ${esiColony.planetId}');

        for (final esiPin in esiPins) {
          pinsCompanions.add(PlanetaryPinsCompanion.insert(
            pinId: esiPin.pinId,
            characterId: characterId,
            planetId: esiColony.planetId,
            typeId: esiPin.typeId,
            typeName: const Value(null), // Will be resolved by itemNameProvider in UI
            latitude: esiPin.latitude,
            longitude: esiPin.longitude,
            installTime: esiPin.installTime,
            expiryTime: Value(esiPin.expiryTime),
            productTypeId: Value(esiPin.productTypeId),
            quantityPerCycle: Value(esiPin.quantityPerCycle),
            cycleTime: Value(esiPin.cycleTime),
            schematicId: Value(esiPin.schematicId),
          ));
        }
      }

      // 3. Save to repository
      await _repository.saveColonies(characterId, coloniesCompanions, pinsCompanions);
      Log.d('PI.SYNC', 'syncColonies($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('PI.SYNC', 'syncColonies($characterId) - FAILED', e, stack);
      rethrow;
    }
  }
}

/// Provider for the planetary sync service.
final planetarySyncServiceProvider = Provider<PlanetarySyncService>((ref) {
  return PlanetarySyncService(
    esiClient: ref.watch(esiClientProvider),
    repository: ref.watch(planetaryRepositoryProvider),
  );
});
