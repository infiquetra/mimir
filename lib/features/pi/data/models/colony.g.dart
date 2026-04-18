// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'colony.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Colony _$ColonyFromJson(Map<String, dynamic> json) => _Colony(
      planetId: (json['planetId'] as num).toInt(),
      planetName: json['planetName'] as String,
      planetType: json['planetType'] as String,
      ownerId: (json['ownerId'] as num).toInt(),
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
      upgradeLevel: (json['upgradeLevel'] as num).toInt(),
      numPins: (json['numPins'] as num).toInt(),
      pins: (json['pins'] as List<dynamic>?)
              ?.map((e) => Pin.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ColonyToJson(_Colony instance) => <String, dynamic>{
      'planetId': instance.planetId,
      'planetName': instance.planetName,
      'planetType': instance.planetType,
      'ownerId': instance.ownerId,
      'lastUpdate': instance.lastUpdate.toIso8601String(),
      'upgradeLevel': instance.upgradeLevel,
      'numPins': instance.numPins,
      'pins': instance.pins,
    };

_Pin _$PinFromJson(Map<String, dynamic> json) => _Pin(
      pinId: (json['pinId'] as num).toInt(),
      typeId: (json['typeId'] as num).toInt(),
      typeName: json['typeName'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      installDate: DateTime.parse(json['installDate'] as String),
      lastCycleStart: json['lastCycleStart'] == null
          ? null
          : DateTime.parse(json['lastCycleStart'] as String),
      lastCycleDuration: (json['lastCycleDuration'] as num?)?.toInt(),
      extractorDetails: json['extractorDetails'] == null
          ? null
          : Extractor.fromJson(
              json['extractorDetails'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PinToJson(_Pin instance) => <String, dynamic>{
      'pinId': instance.pinId,
      'typeId': instance.typeId,
      'typeName': instance.typeName,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'installDate': instance.installDate.toIso8601String(),
      'lastCycleStart': instance.lastCycleStart?.toIso8601String(),
      'lastCycleDuration': instance.lastCycleDuration,
      'extractorDetails': instance.extractorDetails,
    };

_Extractor _$ExtractorFromJson(Map<String, dynamic> json) => _Extractor(
      productId: (json['productId'] as num?)?.toInt(),
      productName: json['productName'] as String?,
      quantityPerCycle: (json['quantityPerCycle'] as num?)?.toInt(),
      cycleTime: (json['cycleTime'] as num?)?.toInt(),
      headCount: (json['headCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ExtractorToJson(_Extractor instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'productName': instance.productName,
      'quantityPerCycle': instance.quantityPerCycle,
      'cycleTime': instance.cycleTime,
      'headCount': instance.headCount,
    };
