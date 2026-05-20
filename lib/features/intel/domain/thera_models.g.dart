// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thera_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TheraConnection _$TheraConnectionFromJson(Map<String, dynamic> json) =>
    _TheraConnection(
      id: json['id'] as String,
      whType: json['wh_type'] as String,
      maxShipSize: json['max_ship_size'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      remainingHours: (json['remaining_hours'] as num).toInt(),
      outSystemId: (json['out_system_id'] as num).toInt(),
      outSystemName: json['out_system_name'] as String,
      outSignature: json['out_signature'] as String,
      inSystemId: (json['in_system_id'] as num).toInt(),
      inSystemClass: json['in_system_class'] as String,
      inSystemName: json['in_system_name'] as String,
      inRegionId: (json['in_region_id'] as num).toInt(),
      inRegionName: json['in_region_name'] as String,
      inSignature: json['in_signature'] as String,
    );

Map<String, dynamic> _$TheraConnectionToJson(_TheraConnection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'wh_type': instance.whType,
      'max_ship_size': instance.maxShipSize,
      'expires_at': instance.expiresAt.toIso8601String(),
      'remaining_hours': instance.remainingHours,
      'out_system_id': instance.outSystemId,
      'out_system_name': instance.outSystemName,
      'out_signature': instance.outSignature,
      'in_system_id': instance.inSystemId,
      'in_system_class': instance.inSystemClass,
      'in_system_name': instance.inSystemName,
      'in_region_id': instance.inRegionId,
      'in_region_name': instance.inRegionName,
      'in_signature': instance.inSignature,
    };
