import '../../../../core/database/app_database.dart';
import '../../../../core/network/esi_client.dart';
import 'models/colony.dart';

/// Repository for managing Planetary Interaction (PI) data.
class PiRepository {
  final EsiClient _esiClient;
  final AppDatabase _db;

  PiRepository(this._esiClient, this._db);

  /// Fetches all colonies for a given character.
  Future<List<Colony>> getColonies(int characterId) async {
    final coloniesDto = await _esiClient.getPlanetaryColonies(characterId);

    final List<Colony> result = [];
    for (final dto in coloniesDto) {
      // Resolve solar system name.
      // In a full implementation, we'd use the database or a cache.
      final systemName = await _resolveSystemName(dto.solarSystemId);

      // Fetch layout to get pin details (needed for status and output)
      final layout =
          await _esiClient.getPlanetaryPlanetLayout(characterId, dto.planetId);

      final pins = layout.pins.map((p) => _mapPin(p)).toList();

      result.add(Colony(
        characterId: characterId,
        planetId: dto.planetId,
        planetType: dto.planetType,
        solarSystemName: systemName,
        solarSystemId: dto.solarSystemId,
        lastUpdated: dto.lastUpdate,
        upgradeLevel: dto.upgradeLevel,
        numPins: dto.numPins,
        pins: pins,
      ));
    }
    return result;
  }

  Pin _mapPin(PlanetaryPin p) {
    if (p.extractorDetails != null) {
      return Extractor(
        pinId: p.pinId,
        typeId: p.typeId,
        typeName: 'Extractor', // Ideally resolved via SDE or Universe names
        latitude: p.latitude,
        longitude: p.longitude,
        productTypeId: p.extractorDetails!.productTypeId,
        lastCycleStart: p.lastCycleStart,
        lastCycleDuration: p.lastCycleDuration != null
            ? Duration(seconds: p.lastCycleDuration!)
            : null,
        expiryTime: p.expiryTime,
        qtyPerCycle: p.extractorDetails!.qtyPerCycle,
      );
    } else if (p.factoryDetails != null) {
      return Factory(
        pinId: p.pinId,
        typeId: p.typeId,
        typeName: 'Factory',
        latitude: p.latitude,
        longitude: p.longitude,
        schematicId: p.factoryDetails!.schematicId,
        schematicName: 'Schematic ${p.factoryDetails!.schematicId}',
      );
    } else {
      // Default to generic Pin or Storage if we can detect it
      return Storage(
        pinId: p.pinId,
        typeId: p.typeId,
        typeName: 'Structure',
        latitude: p.latitude,
        longitude: p.longitude,
        capacity: 0,
        fillPercentage: 0,
      );
    }
  }

  Future<String> _resolveSystemName(int systemId) async {
    // Attempt to get from UniverseNames cache in DB
    // This is a simplified version of the logic in the app.
    try {
      final cached = await (_db.select(_db.universeNames)
            ..where((u) => u.id.equals(systemId)))
          .getSingleOrNull();
      if (cached != null) return cached.name;
    } catch (_) {}

    return 'System $systemId';
  }
}
