import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';

/// Naive X6 origin: untyped success, Current stays valid past 60s+1ms,
/// last-known keeps station/tokens, manual is overwritten on refresh/switch.
class ExplorationOriginService {
  ExplorationOriginService({
    Future<CharacterLocationResult> Function(int characterId)? strictLocation,
    DateTime Function()? clock,
  }) : strictLocation = strictLocation ?? _unimplemented,
       _now = clock ?? DateTime.now;

  final Future<CharacterLocationResult> Function(int characterId)
  strictLocation;
  final DateTime Function() _now;

  static Future<CharacterLocationResult> _unimplemented(int characterId) {
    throw UnimplementedError('strictLocation');
  }

  DateTime now() => _now().toUtc();

  /// Naive: any payload becomes an observation; failures are not typed.
  CharacterLocationResult interpretStrict({
    int? statusCode,
    Map<String, dynamic>? body,
    Object? error,
    DateTime? observedAt,
  }) {
    final id = body?['solar_system_id'];
    return CharacterLocationObserved(
      systemId: id is int ? id : 0,
      observedAt: (observedAt ?? now()).toUtc(),
      stationId: body?['station_id'] as int?,
      structureId: body?['structure_id'] as int?,
    );
  }

  Future<CharacterLocationResult> fetch(int characterId) {
    return strictLocation(characterId);
  }

  /// Naive: [Duration.inSeconds] keeps 60s+1ms current.
  bool isCurrentObservation(DateTime observedAt, DateTime now) {
    return now.toUtc().difference(observedAt.toUtc()).inSeconds <= 60;
  }

  LastKnownOriginRecord rememberLastKnown(
    CharacterLocationObserved observed, {
    String? accessToken,
    String? refreshToken,
  }) {
    return LastKnownOriginRecord(
      systemId: observed.systemId,
      observedAt: observed.observedAt,
      fetchedAt: now(),
      stationId: observed.stationId,
      structureId: observed.structureId,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}

class LastKnownOriginRecord {
  LastKnownOriginRecord({
    required this.systemId,
    required this.observedAt,
    this.fetchedAt,
    this.stationId,
    this.structureId,
    this.accessToken,
    this.refreshToken,
  });

  final int systemId;
  final DateTime observedAt;
  final DateTime? fetchedAt;
  final int? stationId;
  final int? structureId;
  final String? accessToken;
  final String? refreshToken;

  Map<String, dynamic> toPersistedJson() => {
    'systemId': systemId,
    'observedAt': observedAt.toUtc().toIso8601String(),
    if (fetchedAt != null) 'fetchedAt': fetchedAt!.toUtc().toIso8601String(),
    if (stationId != null) 'stationId': stationId,
    if (structureId != null) 'structureId': structureId,
    if (accessToken != null) 'accessToken': accessToken,
    if (refreshToken != null) 'refreshToken': refreshToken,
  };
}

class ExplorationOriginController {
  ExplorationOriginController({required this.service});

  final ExplorationOriginService service;

  var generation = 0;
  OriginSelection origin = const UnselectedOrigin();
  CharacterLocationResult? published;
  LastKnownOriginRecord? lastKnown;

  void setManual(int systemId) {
    origin = ManualOrigin(systemId);
  }

  void applyLocation(
    CharacterLocationResult result, {
    required int characterId,
  }) {
    if (result is CharacterLocationObserved) {
      lastKnown = service.rememberLastKnown(result);
      origin = CurrentCharacterOrigin(
        characterId: characterId,
        systemId: result.systemId,
        observedAt: result.observedAt,
      );
      published = result;
      return;
    }
    if (lastKnown != null) {
      origin = LastKnownCharacterOrigin(
        characterId: characterId,
        systemId: lastKnown!.systemId,
        observedAt: lastKnown!.observedAt,
      );
    }
    published = result;
  }

  Future<void> fetchCurrent(int characterId) async {
    final result = await service.fetch(characterId);
    applyLocation(result, characterId: characterId);
  }

  void switchCharacter(int characterId) {
    generation++;
    origin = const UnselectedOrigin();
  }
}
