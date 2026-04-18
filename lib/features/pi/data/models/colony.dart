import 'package:freezed_annotation/freezed_annotation.dart';

part 'colony.freezed.dart';
part 'colony.g.dart';

enum ColonyStatus { unknown, running, notRunning, expiring }

@freezed
abstract class Colony with _$Colony {
  const Colony._();

  const factory Colony({
    required int characterId,
    required int planetId,
    required String planetType,
    required String solarSystemName,
    required int solarSystemId,
    required DateTime lastUpdated,
    required int upgradeLevel,
    required int numPins,
    @Default([]) List<Pin> pins,
  }) = _Colony;

  factory Colony.fromJson(Map<String, dynamic> json) => _$ColonyFromJson(json);

  ColonyStatus get status {
    final extractors = pins.whereType<Extractor>();
    if (extractors.isEmpty) return ColonyStatus.unknown;

    bool anyExpiring = false;
    bool anyRunning = false;
    bool anyIdle = false;

    final now = DateTime.now();

    for (final e in extractors) {
      if (e.lastCycleStart == null) {
        anyIdle = true;
        continue;
      }

      if (e.expiryTime != null) {
        if (e.expiryTime!.isBefore(now)) {
          anyIdle = true;
        } else if (e.expiryTime!.difference(now).inHours < 1) {
          anyExpiring = true;
        } else {
          anyRunning = true;
        }
      } else {
        anyIdle = true;
      }
    }

    if (anyExpiring) return ColonyStatus.expiring;
    if (anyRunning) return ColonyStatus.running;
    if (anyIdle) return ColonyStatus.notRunning;
    return ColonyStatus.unknown;
  }

  @override
  String toString() {
    return 'Colony(characterId: $characterId, planetId: $planetId, '
        'planetType: $planetType, solarSystem: $solarSystemName, '
        'upgradeLevel: $upgradeLevel, numPins: $numPins, status: $status)';
  }
}

@freezed
abstract class Pin with _$Pin {
  const factory Pin.extractor({
    required int pinId,
    required int typeId,
    String? typeName,
    required double latitude,
    required double longitude,
    required int productTypeId,
    DateTime? lastCycleStart,
    Duration? lastCycleDuration,
    DateTime? expiryTime,
    int? qtyPerCycle,
  }) = Extractor;

  const factory Pin.factory({
    required int pinId,
    required int typeId,
    String? typeName,
    required double latitude,
    required double longitude,
    required int schematicId,
    String? schematicName,
  }) = Factory;

  const factory Pin.storage({
    required int pinId,
    required int typeId,
    String? typeName,
    required double latitude,
    required double longitude,
    required int capacity,
    required double fillPercentage,
  }) = Storage;

  factory Pin.fromJson(Map<String, dynamic> json) => _$PinFromJson(json);
}
