import '../../../core/auth/token_manager.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import '../../fitting/domain/models.dart';
import '../domain/aar_fit_snapshot.dart';
import '../domain/combat_fit_snapshot_mapper.dart';
import '../domain/parsed_combat_encounter.dart';

class CurrentShipFitRead {
  const CurrentShipFitRead({
    required this.characterId,
    required this.fitting,
    required this.knowledge,
    required this.sourceItemIds,
    required this.capturedAt,
    this.limitations = const [],
  });

  final int characterId;
  final Fitting fitting;
  final FitInventoryKnowledge knowledge;
  final List<int> sourceItemIds;
  final DateTime capturedAt;
  final List<String> limitations;
}

enum CurrentShipFitReadFailure { authUnavailable, noShip, captureFailure }

class CurrentShipFitReadException implements Exception {
  const CurrentShipFitReadException(this.kind, [this.cause]);

  final CurrentShipFitReadFailure kind;
  final Object? cause;

  @override
  String toString() => 'CurrentShipFitReadException($kind)';
}

/// Encounter-character ship/assets reader for comparison capture.
///
/// Does not call AssetSyncService.
class CurrentShipFitReader {
  CurrentShipFitReader({
    required EsiClient esiClient,
    required TokenManager tokenManager,
    DateTime Function()? clock,
  }) : _esiClient = esiClient,
       _tokenManager = tokenManager,
       _clock = clock ?? DateTime.now;

  final EsiClient _esiClient;
  final TokenManager _tokenManager;
  final DateTime Function() _clock;

  Future<CurrentShipFitRead> read(ParsedCombatEncounter encounter) async {
    final characterId = encounter.characterId;
    if (characterId == null) {
      throw const CurrentShipFitReadException(
        CurrentShipFitReadFailure.authUnavailable,
      );
    }
    final tokens = await _tokenManager.getTokens(characterId);
    if (tokens == null) {
      throw const CurrentShipFitReadException(
        CurrentShipFitReadFailure.authUnavailable,
      );
    }

    final CharacterShip ship;
    try {
      ship = await _esiClient.getCharacterShipStrict(characterId);
    } on EsiException catch (error, stack) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        Error.throwWithStackTrace(
          const CurrentShipFitReadException(
            CurrentShipFitReadFailure.authUnavailable,
          ),
          stack,
        );
      }
      if (error.statusCode == 404) {
        Error.throwWithStackTrace(
          CurrentShipFitReadException(CurrentShipFitReadFailure.noShip, error),
          stack,
        );
      }
      Error.throwWithStackTrace(
        CurrentShipFitReadException(
          CurrentShipFitReadFailure.captureFailure,
          error,
        ),
        stack,
      );
    } catch (error, stack) {
      Error.throwWithStackTrace(
        CurrentShipFitReadException(
          CurrentShipFitReadFailure.captureFailure,
          error,
        ),
        stack,
      );
    }

    final List<AssetItem> assets;
    try {
      assets = await _fetchAllAssets(characterId);
    } on CurrentShipFitReadException {
      rethrow;
    } catch (error, stack) {
      Error.throwWithStackTrace(
        CurrentShipFitReadException(
          CurrentShipFitReadFailure.captureFailure,
          error,
        ),
        stack,
      );
    }
    final mapped = CombatFitSnapshotMapper.mapCurrentShipAssets(
      characterId: characterId,
      ship: ship,
      assets: assets,
    );
    final fitting = _copyFitting(mapped);
    final emptyInventory =
        fitting.allModules.isEmpty &&
        fitting.drones.isEmpty &&
        fitting.fighters.isEmpty &&
        fitting.cargo.isEmpty;
    final sourceItemIds = <int>{
      ship.shipItemId,
      for (final asset in assets) asset.itemId,
    }.toList();
    Log.i(
      'AAR',
      'current ship read character=$characterId ship=${fitting.shipTypeId} '
          'modules=${fitting.allModules.length} empty=$emptyInventory',
    );
    return CurrentShipFitRead(
      characterId: characterId,
      fitting: fitting,
      knowledge: emptyInventory
          ? FitInventoryKnowledge(
              groups: {
                for (final group in FitInventoryGroup.values)
                  group: FitGroupKnowledge(
                    completeness: InventoryCompleteness.unknown,
                    applicability: GroupApplicability.applicable,
                    positions: SlotPositionMeaning.recorded,
                  ),
              },
              moduleState: StateKnowledge.assumed,
            )
          : FitInventoryKnowledge.recordedComplete(
              positions: SlotPositionMeaning.recorded,
              moduleState: StateKnowledge.assumed,
            ),
      sourceItemIds: sourceItemIds,
      capturedAt: _clock().toUtc(),
      limitations: [
        if (emptyInventory)
          'No fitted modules were present on the captured hull.',
      ],
    );
  }

  Future<List<AssetItem>> _fetchAllAssets(int characterId) async {
    final first = await _esiClient.getCharacterAssets(characterId, page: 1);
    final totalPages = _assetTotalPages(first.headers);
    final assets = <AssetItem>[...first.data];
    for (var page = 2; page <= totalPages; page++) {
      final response = await _esiClient.getCharacterAssets(
        characterId,
        page: page,
      );
      assets.addAll(response.data);
    }
    return assets;
  }

  int _assetTotalPages(Map<String, List<String>> headers) {
    if (!headers.containsKey('x-pages')) {
      return 1;
    }
    final values = headers['x-pages']!;
    if (values.isEmpty) {
      throw const CurrentShipFitReadException(
        CurrentShipFitReadFailure.captureFailure,
      );
    }
    final parsed = int.tryParse(values.first);
    if (parsed == null || parsed < 1) {
      throw const CurrentShipFitReadException(
        CurrentShipFitReadFailure.captureFailure,
      );
    }
    return parsed;
  }
}

Fitting _copyFitting(Fitting fitting) {
  return Fitting(
    id: fitting.id,
    name: fitting.name,
    description: fitting.description,
    shipTypeId: fitting.shipTypeId,
    shipName: fitting.shipName,
    highSlots: List<FittedModule>.from(fitting.highSlots),
    medSlots: List<FittedModule>.from(fitting.medSlots),
    lowSlots: List<FittedModule>.from(fitting.lowSlots),
    rigSlots: List<FittedModule>.from(fitting.rigSlots),
    subsystems: List<FittedModule>.from(fitting.subsystems),
    drones: List<DroneGroup>.from(fitting.drones),
    fighters: List<FighterGroup>.from(fitting.fighters),
    cargo: List<CargoItem>.from(fitting.cargo),
  );
}
