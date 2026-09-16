import 'package:mimir/core/logging/logger.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';

/// Origin modes, current 60s freshness, and last-known persistence.
class ExplorationOriginService {
  ExplorationOriginService({
    Future<CharacterLocationResult> Function(int characterId)? strictLocation,
    DateTime Function()? clock,
  }) : strictLocation = strictLocation ?? _unimplemented,
       _now = clock ?? DateTime.now;

  static const currentWindow = Duration(milliseconds: 60000);

  final Future<CharacterLocationResult> Function(int characterId)
  strictLocation;
  final DateTime Function() _now;

  static Future<CharacterLocationResult> _unimplemented(int characterId) {
    throw UnimplementedError('strictLocation');
  }

  DateTime now() => _now().toUtc();

  CharacterLocationResult interpretStrict({
    int? statusCode,
    Map<String, dynamic>? body,
    Object? error,
    DateTime? observedAt,
  }) {
    return interpretCharacterLocationResponse(
      statusCode: statusCode,
      body: body,
      error: error,
      observedAt: observedAt ?? now(),
    );
  }

  Future<CharacterLocationResult> fetch(int characterId) {
    return strictLocation(characterId);
  }

  /// Current while age ≤ 60_000 ms; outdated at 60s + 1ms.
  bool isCurrentObservation(DateTime observedAt, DateTime now) {
    return now.toUtc().difference(observedAt.toUtc()) <= currentWindow;
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
    );
  }
}

class LastKnownOriginRecord {
  LastKnownOriginRecord({
    required this.systemId,
    required this.observedAt,
    this.fetchedAt,
  });

  final int systemId;
  final DateTime observedAt;
  final DateTime? fetchedAt;

  Map<String, dynamic> toPersistedJson() => {
    'systemId': systemId,
    'observedAt': observedAt.toUtc().toIso8601String(),
    if (fetchedAt != null) 'fetchedAt': fetchedAt!.toUtc().toIso8601String(),
  };
}

class ExplorationOriginController {
  ExplorationOriginController({required this.service});

  static const _log = 'EXPLORATION.PROVIDER';

  final ExplorationOriginService service;

  var generation = 0;
  OriginSelection origin = const UnselectedOrigin();
  CharacterLocationResult? published;
  LastKnownOriginRecord? lastKnown;

  void setManual(int systemId) {
    origin = ManualOrigin(systemId);
    Log.i(_log, 'manual origin $systemId');
  }

  void applyLocation(
    CharacterLocationResult result, {
    required int characterId,
  }) {
    if (result is CharacterLocationObserved) {
      lastKnown = service.rememberLastKnown(result);
    }
    if (origin is ManualOrigin) {
      Log.d(_log, 'manual origin retained through location update');
      return;
    }
    if (result is CharacterLocationObserved) {
      origin = CurrentCharacterOrigin(
        characterId: characterId,
        systemId: result.systemId,
        observedAt: result.observedAt,
      );
      published = result;
      return;
    }
    published = result;
  }

  Future<void> fetchCurrent(int characterId) async {
    final gen = generation;
    final result = await service.fetch(characterId);
    if (gen != generation) {
      published = null;
      Log.i(_log, 'dropped late location for character $characterId');
      return;
    }
    applyLocation(result, characterId: characterId);
  }

  void switchCharacter(int characterId) {
    generation++;
    published = null;
    if (origin is ManualOrigin) {
      Log.d(_log, 'manual origin survives switch to $characterId');
      return;
    }
    origin = const UnselectedOrigin();
  }
}
