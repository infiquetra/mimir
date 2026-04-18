import 'package:freezed_annotation/freezed_annotation.dart';

part 'colony.freezed.dart';
part 'colony.g.dart';

@freezed
abstract class Colony with _$Colony {
  const factory Colony({
    required int planetId,
    required String planetName,
    required String planetType,
    required int ownerId,
    required DateTime lastUpdate,
    required int upgradeLevel,
    required int numPins,
    @Default([]) List<Pin> pins,
  }) = _Colony;

  factory Colony.fromJson(Map<String, dynamic> json) => _$ColonyFromJson(json);
}

@freezed
abstract class Pin with _$Pin {
  const factory Pin({
    required int pinId,
    required int typeId,
    String? typeName,
    required double latitude,
    required double longitude,
    required DateTime installDate,
    DateTime? lastCycleStart,
    int? lastCycleDuration,
    Extractor? extractorDetails,
  }) = _Pin;

  factory Pin.fromJson(Map<String, dynamic> json) => _$PinFromJson(json);
}

@freezed
abstract class Extractor with _$Extractor {
  const factory Extractor({
    int? productId,
    String? productName,
    int? quantityPerCycle,
    int? cycleTime,
    int? headCount,
  }) = _Extractor;

  factory Extractor.fromJson(Map<String, dynamic> json) => _$ExtractorFromJson(json);
}
