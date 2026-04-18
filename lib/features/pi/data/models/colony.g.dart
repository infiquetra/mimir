// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'colony.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Colony _$ColonyFromJson(Map<String, dynamic> json) => _Colony(
      characterId: (json['characterId'] as num).toInt(),
      planetId: (json['planetId'] as num).toInt(),
      planetType: json['planetType'] as String,
      solarSystemName: json['solarSystemName'] as String,
      solarSystemId: (json['solarSystemId'] as num).toInt(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      upgradeLevel: (json['upgradeLevel'] as num).toInt(),
      numPins: (json['numPins'] as num).toInt(),
      pins: (json['pins'] as List<dynamic>?)
              ?.map((e) => Pin.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ColonyToJson(_Colony instance) => <String, dynamic>{
      'characterId': instance.characterId,
      'planetId': instance.planetId,
      'planetType': instance.planetType,
      'solarSystemName': instance.solarSystemName,
      'solarSystemId': instance.solarSystemId,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
      'upgradeLevel': instance.upgradeLevel,
      'numPins': instance.numPins,
      'pins': instance.pins,
    };

Extractor _$ExtractorFromJson(Map<String, dynamic> json) => Extractor(
      pinId: (json['pinId'] as num).toInt(),
      typeId: (json['typeId'] as num).toInt(),
      typeName: json['typeName'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      productTypeId: (json['productTypeId'] as num).toInt(),
      lastCycleStart: json['lastCycleStart'] == null
          ? null
          : DateTime.parse(json['lastCycleStart'] as String),
      lastCycleDuration: json['lastCycleDuration'] == null
          ? null
          : Duration(microseconds: (json['lastCycleDuration'] as num).toInt()),
      expiryTime: json['expiryTime'] == null
          ? null
          : DateTime.parse(json['expiryTime'] as String),
      qtyPerCycle: (json['qtyPerCycle'] as num?)?.toInt(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$ExtractorToJson(Extractor instance) => <String, dynamic>{
      'pinId': instance.pinId,
      'typeId': instance.typeId,
      'typeName': instance.typeName,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'productTypeId': instance.productTypeId,
      'lastCycleStart': instance.lastCycleStart?.toIso8601String(),
      'lastCycleDuration': instance.lastCycleDuration?.inMicroseconds,
      'expiryTime': instance.expiryTime?.toIso8601String(),
      'qtyPerCycle': instance.qtyPerCycle,
      'runtimeType': instance.$type,
    };

Factory _$FactoryFromJson(Map<String, dynamic> json) => Factory(
      pinId: (json['pinId'] as num).toInt(),
      typeId: (json['typeId'] as num).toInt(),
      typeName: json['typeName'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      schematicId: (json['schematicId'] as num).toInt(),
      schematicName: json['schematicName'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$FactoryToJson(Factory instance) => <String, dynamic>{
      'pinId': instance.pinId,
      'typeId': instance.typeId,
      'typeName': instance.typeName,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'schematicId': instance.schematicId,
      'schematicName': instance.schematicName,
      'runtimeType': instance.$type,
    };

Storage _$StorageFromJson(Map<String, dynamic> json) => Storage(
      pinId: (json['pinId'] as num).toInt(),
      typeId: (json['typeId'] as num).toInt(),
      typeName: json['typeName'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      capacity: (json['capacity'] as num).toInt(),
      fillPercentage: (json['fillPercentage'] as num).toDouble(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$StorageToJson(Storage instance) => <String, dynamic>{
      'pinId': instance.pinId,
      'typeId': instance.typeId,
      'typeName': instance.typeName,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'capacity': instance.capacity,
      'fillPercentage': instance.fillPercentage,
      'runtimeType': instance.$type,
    };
